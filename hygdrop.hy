(import os
	irc.bot
	[hy.importer [import_file_to_module]])

(def plugins [])

(defun welcome-handler [connection event]
  (foreach [(, dir subdir files) (os.walk
				  (os.path.join (os.path.dirname
						 (os.path.realpath __file__))
						 "plugins"))]
    (foreach [file files]
      (if (.endswith file ".hy")
	(.append plugins (import_file_to_module (get (.split file ".") 0)
						(os.path.join dir file))))))
  (.join connection "#hy"))

(defun pubmsg-handler [connection event]
  (let [[arg (get event.arguments 0)]]
    (foreach [plugin plugins]
      (.process plugin connection event arg))))

(defun start[]
  (let [[bot
	 (irc.bot.SingleServerIRCBot [(, "irc.freenode.net" 6667)]
				     "hygdrop" "Hy five!")]]
    (.add_global_handler bot.connection "welcome" welcome-handler)
    (.add_global_handler bot.connection "pubmsg" pubmsg-handler)
    (.start bot)))

(if (= __name__ "__main__")
  (start))
