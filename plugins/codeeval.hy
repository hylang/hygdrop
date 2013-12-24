(import ast
	sys
	builtins
	astor
	[io [StringIO]]
	[time [sleep]]
	[hy.importer [import_buffer_to_hst ast_compile]]
	[hy.compiler [hy_compile]]
	[hy.cmdline [HyREPL]])

(def hr (HyREPL))

(defn dump-exception [e]
  (.write sys.stderr (str e))
  (.write sys.stderr "\n")
  (.flush sys.stderr))

(defun eval-code [connection target code]
  (setv sys.stdout (StringIO))
  ;; (builtins.eval (ast_compile (-> (import_buffer_to_hst code)
  ;; 				  (hy_compile __name__ ast.Interactive))
  ;; 			      "<input>" "single"))
  (.runsource hr code)
  (.privmsg connection target (.replace (.getvalue sys.stdout) "\n" " ")))

(defun source-code [connection target hy-code]
  (let [[astorcode (-> (import_buffer_to_hst hy-code)
		       (hy_compile __name__ ))]
	[pysource (.to_source astor.codegen astorcode)]]
    (foreach [line (.split pysource "\n")]
      (.privmsg connection target line)
      (sleep 0.5))))

(defun process [connection event message]
  (try
   (progn
    (if (or (.startswith message ",")
	    (.startswith message (+ connection.nickname ": ")))
      (progn
       (setv code-startpos ((fn[] (if (.startswith message ",") 1
				      (+ (len connection.nickname) 1)))))
       (eval-code connection event.target (slice message code-startpos))))
    (if (.startswith message "!source")
      (source-code connection event.target (slice message
						  (+ (len "!source") 1)))))
   (catch [e Exception]
     (try
      (foreach [line (.split (str e) "\n")]
	(.notice connection event.target line)
	(sleep 0.5))
      (catch [f Exception]
	(progn
	 (dump-exception e)
	 (dump-exception f)))))))
