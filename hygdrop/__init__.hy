(import irc.bot)
(import ast)
(import sandbox)
(import hy.importer)
(import hy.compiler)
(import __builtin__)
(import cStringIO)
(import sys)


(defn on-welcome [connection event]
  (.join connection "#hy"))

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
                 (hy.importer.compile_
                  (hy.compiler.hy_compile
                   (hy.importer.import_buffer_to_hst (cStringIO.StringIO code))
                   ast.Interactive)
                  "IRC"
                  "single"))))
        (try
          (do
            (setv sys.stdout (cStringIO.StringIO))
            (.call bsandbox compiled-code)
            (.privmsg connection event.target
                      (.replace (.getvalue sys.stdout) "\n" " ")))
          (except [e Exception]
                  (try
                    (.privmsg connection event.target
                              (.replace (str e) "\n" " "))
                    (except []
                            (do (.write sys.stderr (str e))
                                (.flush sys.stderr))))))))))

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
