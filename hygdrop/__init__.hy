(import irc.bot)
(import ast)
(import sandbox)
(import hy.importer)
(import hy.compiler)
(import __builtin__)
(import StringIO)
(import sys)
(import time)

(defn on-welcome [connection event]
  (.join connection "#hy-test"))

(defn dump-exception [e]
  (.write sys.stderr (str e))
  (.write sys.stderr "\n")
  (.flush sys.stderr))

(defn on-pubmsg [connection event]
  (let [[arg (get event.arguments 0)]
        [code null]
        [bsandbox null]
        [sandbox-config null]
        [compiled-code null]]
    (if (.startswith arg (+ connection.nickname ": "))
      (do
        (setv sandbox-config (sandbox.SandboxConfig "stdout"))
        (.allowModule sandbox-config "hy.core.bootstrap")
        (.allowModule sandbox-config "hy.core.mangles")
        (setv bsandbox (sandbox.Sandbox sandbox-config))
        (setv code (slice arg (+ (len connection.nickname) 2)))
        (setv compiled-code
              (fn []
                (__builtin__.eval
                 (hy.importer.ast_compile
                  (hy.compiler.hy_compile
                   (hy.importer.import_buffer_to_hst code)
                   ast.Interactive)
                  "IRC"
                  "single"))))
        (try
          (do
            (setv sys.stdout (StringIO.StringIO))
            (.call bsandbox compiled-code)
            (.privmsg connection event.target
                      (.replace (.getvalue sys.stdout) "\n" " ")))
          (except [e Exception]
                  (try
                    (for [line (.split (.decode (str e) "utf-8") "\n")]
                      (.notice connection event.target line)
                      (time.sleep 0.5))
                    (except [f Exception]
                            (do (dump-exception e)
                                (dump-exception f))))))))))

(defn start []
  (let [[bot
         (irc.bot.SingleServerIRCBot [(, "irc.freenode.net" 6667)]
                                     "hygdrop"
                                     "Hy five!")]]
    (.add_global_handler bot.connection "welcome" on-welcome)
    (.add_global_handler bot.connection "pubmsg" on-pubmsg)
    (.start bot)))

(if (= __name__ "__main__")
  (start))
