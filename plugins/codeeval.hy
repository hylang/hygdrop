(import ast
        sys
        builtins
        astor
        requests
        code
        traceback
        [io [StringIO]]
        [time [sleep]]
        [hy.lex [LexException PrematureEndOfInput tokenize]]
        [hy.importer [import_buffer_to_hst ast_compile]]
        [hy.compiler [hy_compile HyTypeError]])


(defclass HygdropREPL [code.InteractiveConsole]
  "Hygdrops REPL - Class is a REPL to execute the code for Hygdrop,
  this class doesn't strictly adhere to REPL rules and raises
  exception so it can be communicated to end user."
  [[--init--
    (fn [self &optional [locals null] [filename "<input"]]
      (apply code.InteractiveConsole.__init__  [self]
               {"locals" locals "filename" filename}))]
   [runsource
    (fn [self source &optional [filename "<input>"] [symbol "single"]]
      (try
       (setv tokens (tokenize source))
       (catch [p PrematureEndOfInput]
         (progn
          (.setexception-source self p source filename)
          (raise p)))
       (catch [l LexException]
         (progn
          (.setexception-source self l source filename)
          (raise l))))
      (try
       (progn
        (setv -ast (hy_compile tokens "__console__" ast.Interactive))
        (setv code (ast_compile -ast filename symbol)))
       (catch [ht HyTypeError]
         (progn
          (.setexception-source self ht source filename)
          (raise ht)))
       (catch [e Exception]
         (raise e)))
      (.runcode self code)
      False)]
   [setexception-source
    (fn [self e source filename]
      "When exceptions are raised if e.source is not set then set it to
  current source otherwise the code will break at __str__
  function. This functions are called only for Hy specific  exceptions"
      (if (= e.source None)
        (setv e.source source)
        (setv e.filename filename)))]])

(def *hr* (HygdropREPL))

(defmacro paste-code [payload &rest body]
  `(let [[r (.post requests "https://www.refheap.com/api/paste" ~payload)]]
     ~@body))

(defun dump-exception [connection target e]
  (paste-code {"contents" (str e) "language" "Python Traceback"}
              (if (= r.status_code 201)
                (.privmsg connection target
                          (.format "Aargh something broke, traceback: {}"
                                   (get (.json r) "url")))
                (progn
                 (.write sys.stderr (str e))
                 (.write sys.stderr "\n")
                 (.flush sys.stderr)))))

(defun dump-traceback [connection target]
  (let [[tblist (.extract_tb traceback sys.last_traceback)]
        [lines (.format_list traceback (cdr tblist))]]
    (if lines
      (.insert lines 0 "Traceback (most recent call last):\n"))
    (.extend lines (.format_exception_only traceback sys.last_type
                                           sys.last_value))
    (paste-code {"contents" (.join "" lines) "language" "Python Traceback"}
                (if (= r.status_code 201)
                  (.privmsg connection target
                            (.format "Aargh something broke, traceback {}"
                                     (get (.json r) "url")))
                  (for [line (.split lines "\n")]
                    (.privmsg connection target line)
                    (sleep 0.5))))
    ;; Cleanup the sys attributes so that we can recognize next error,
    ;; if not cleared this will get always executed that is IIUC.
    (delattr sys "last_value")
    (delattr sys "last_type")
    (delattr sys "last_traceback")
    (setv tblist null)))

(defun eval-code [connection target code &optional [dry-run False]]
  (setv sys.stdout (StringIO))
  (.runsource *hr* code)
  ;; (exec (ast_compile (-> (import_buffer_to_hst code)
  ;;                              (hy_compile "__main__" ast.Interactive))
  ;;                          "<input>" "single"))
  (if dry-run
    (.replace (.getvalue sys.stdout) "\n" " ")
    (let [[output (.getvalue sys.stdout)]
          [message ["Output was too long bro, so here is the paste:"]]]
      (if (or (>= (len output) 512) (!= (.find output "\n") -1))
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
      (if (or (!= (.find pysource "\n") -1) (>= (len pysource) 512))
        (paste-code {"contents" pysource "language" "Python"}
                    (if (= r.status_code 201)
                      (.privmsg connection target
                                (.format "Yo bro your source is ready at {}"
                                         (get (.json r) "url")))
                      (.privmsg connection target
                                "Something went wrong while creating paste")))
        (for [srcline (.split pysource "\n")]
          (.privmsg connection target srcline)
          (sleep 0.5))))))

(defun process [connection event message]
  (try
   (progn
    (if (or (.startswith message ",")
            (.startswith message (+ connection.nickname ": ")))
      (progn
       (setv code-startpos ((fn[] (if (.startswith message ",") 1
                                      (+ (len connection.nickname) 1)))))
       (eval-code connection event.target (slice message code-startpos))
       ;; check if an error occured and is printed by show_traceback
       ;; of REPL to stderr in that case print this traceback to IRC
       (if (hasattr sys "last_traceback")
         (dump-traceback connection event.target))))
    (if (.startswith message "!source")
      (source-code connection event.target (slice message
                                                  (+ (len "!source") 1)))))
   (catch [e Exception]
     (try
      (for [line (.split (str e) "\n")]
        (.privmsg connection event.target line)
        (sleep 0.5))
      (catch [f Exception]
        (progn
         (dump-exception connection event.target e)
         (dump-exception connection event.target f)))))))
