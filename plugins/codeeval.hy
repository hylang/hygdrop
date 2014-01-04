(import ast
	sys
	builtins
	astor
	requests
	[io [StringIO]]
	[time [sleep]]
	[hy.importer [import_buffer_to_hst ast_compile]]
	[hy.compiler [hy_compile]]
	[hy.cmdline [HyREPL]])

(def *hr* (HyREPL))

(defmacro paste-code [payload &rest body]
  `(let [[r (.post requests "https://www.refheap.com/api/paste" ~payload)]]
     ~@body))

(defn dump-exception [connection target e]
  (paste-code {"contents" (str e) "language" "Python Traceback"}
	      (if (= r.status_code 201)
		(.privmsg connection target
			  (.format "Aargh something broke {}"
				   (get (.json r) "url")))
		(progn
		 (.write sys.stderr (str e))
		 (.write sys.stderr "\n")
		 (.flush sys.stderr)))))

(defun eval-code [connection target code &optional [dry-run False]]
  (setv sys.stdout (StringIO))
  (.runsource *hr* code)
  ;; (exec (ast_compile (-> (import_buffer_to_hst code)
  ;; 				  (hy_compile "__main__" ast.Interactive))
  ;; 			      "<input>" "single"))
  (if dry-run
    (.replace (.getvalue sys.stdout) "\n" " ")
    (let [[output (.getvalue sys.stdout)]
	  [message ["Output was too long bro, so here is the paste:"]]]
      (if (>= (len output) 512)
	(paste-code {"contents" output "language" "IRC Logs"}
		    (if (= r.status_code 201)
		      (progn
		       (.append message (get (.json r) "url"))
		       (.privmsg connection target (.join " " message)))))
	(.privmsg connection target (.replace output "\n" " "))))))

(defun source-code [connection target hy-code &optional [dry-run False]]
  (let [[astorcode (-> (import_buffer_to_hst hy-code)
		       (hy_compile __name__ ))]
	[pysource (.to_source astor.codegen astorcode)]]
    (if dry-run
      pysource
      (paste-code {"contents" pysource "language" "Python"}
		  (if (= r.status_code 201)
		    (.privmsg connection target
			      (.format "Yo bro your source is ready at {}"
				       (get (.json r) "url")))
		    (.privmsg connection target
			      "Something went wrong while creating paste"))))))

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
      (for [line (.split (str e) "\n")]
	(.notice connection event.target line)
	(sleep 0.5))
      (catch [f Exception]
	(progn
	 (dump-exception connection event.target e)
	 (dump-exception connection event.target f)))))))
