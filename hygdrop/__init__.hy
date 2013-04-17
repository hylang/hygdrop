(import irc.bot)

(defn on-welcome [bot event]
  (.join bot "#hy"))

(defn start []
  (let [[bot
         (irc.bot.SingleServerIRCBot [(, "irc.freenode.net" 6667)]
                                     "hygdrop"
                                     "Hy five!")]]
    (.add_global_handler bot.connection "welcome" on-welcome)
    (.start bot)))

(if (= __name__ "__main__")
  (start))
