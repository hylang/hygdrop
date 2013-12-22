(import ast
	re
	hy.importer
	hy.compiler
	[functools [partial]]
	[github [get-github-issue get-github-commit
		 get-core-members]])

(defun handle-github-msg [github-fn github-msg
			  &optional [dry-run False]]
  (let [[project (.group github-msg "project")]
	[repo (.group github-msg "repo")]
	[query (.group github-msg "query")]]
    (if (not project) (setv project "hylang"))
    (if (not repo) (setv repo "hy"))
    (kwapply (github-fn query) {"project" project "repo" repo
					  "dry_run" (if dry-run True False)})))

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
    (if (or (.startswith arg ", ")
	    (.startswith arg (+ connection.nickname ": ")))
      (progn
       (if (not (= (re.search
		    "(?:(.*core team.*members?.*|.*members?.*core team.*))"
		    arg) null))
	 (get-core-members connection event.target)
	 (do
	  (print "Code Evaluation not implemented")))))))
