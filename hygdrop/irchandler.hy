(import ast
	sys
	re
	builtins
	[hy.importer [ast_compile import_buffer_to_hst
		      import_buffer_to_module]]
	[hy.compiler [hy_compile]]
	[functools [partial]]
	[github [get-github-issue get-github-commit
		 get-core-members]]
	[io [StringIO]]
	[time [sleep]])

(defun handle-github-msg [github-fn github-msg
			  &optional [dry-run False]]
  (let [[project (.group github-msg "project")]
	[repo (.group github-msg "repo")]
	[query (.group github-msg "query")]]
    (if (not project) (setv project "hylang"))
    (if (not repo) (setv repo "hy"))
    (kwapply (github-fn query) {"project" project "repo" repo
					  "dry_run" (if dry-run True False)})))

(defun eval-code [code]
  (import-buffer-to-module __name__ code)
  (setv sys.stdout (StringIO))
  (builtins.eval (ast_compile (-> (import_buffer_to_hst code)
				  (hy_compile __name__ ast.Interactive))
			      "IRC" "single"))
  (.replace (.getvalue sys.stdout) "\n" " "))

(defn dump-exception [e]
  (.write sys.stderr (str e))
  (.write sys.stderr "\n")
  (.flush sys.stderr))

(defun pubmsg-handler [connection event]
  (let [[arg (get event.arguments 0)]
	[code null]
	[issue-msg (re.search "(((?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?#(?P<query>\\d+)"
			      arg)]
	[commit-msg (re.search "(((?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?@(?P<query>[a-f0-9]+)"
			       arg)]
	[issue-fn (partial get-github-issue connection event.target)]
	[commit-fn (partial get-github-commit connection event.target)]]
    (if issue-msg
      (handle-github-msg issue-fn issue-msg))
    (if commit-msg
      (handle-github-msg commit-fn commit-msg))
    (if (or (.startswith arg ",")
	    (.startswith arg (+ connection.nickname ": ")))
      (if (not (= (re.search
		   "(?:(.*core team.*members?.*|.*members?.*core team.*))"
		   arg) null))
	(get-core-members connection event.target)
	(do
	 (setv code-startpos ((fn[] (if (.startswith arg ",") 1
					(+ (len connection.nickname) 2)))))
	 (try
	  (.privmsg connection event.target
		    (eval-code
		     (slice arg code-startpos)))
	  (catch [e Exception]
	    (try
	     (for [line (.split (str e) "\n")]
	       (.notice connection event.target line)
	       (sleep 0.5))
	     (catch [f Exception]
	       (progn
		(dump-exception e)
		(dump-exception f)))))))))))
