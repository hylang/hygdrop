(import os
	irc.bot
	[hy.importer [import_file_to_module]]
	[docopt [docopt]])

(def *plugins* [])
(def *usage* "Hygdrop - Hy IRC bot
Usage:
hygdrop.hy
hygdrop.hy [--server=<server>] [--channel=<channel>] [--port=<portnum>] [--nick=<nick>]
hygdrop.hy [-h | --help]
hygdrop.hy [-v | --version]
hygdrop.hy [--dry-run]

Options:
-h --help                     Show this help screen
-v --version                  Show version
--server=<server:port>        Servers to connect
--channel=<channel>,<channel> Channel to join
--port=<portnumber>           Port number to connect to IRC server
--nick=<nickname>             Nick the bot should use")

(def *arguments* (apply docopt [*usage*] {"version" "Hygdrop 0.1"}))

(defun welcome-handler [connection event]
  (for [(, dir subdir files) (os.walk (-> (os.path.dirname
					       (os.path.realpath __file__))
					      (os.path.join "plugins")))]
    (for [file files]
      (if (.endswith file ".hy")
	(.append *plugins* (import_file_to_module (get (.split file ".") 0)
						  (os.path.join dir file))))))
  (if (get *arguments* "--channel")
    (for [channel (.split (get *arguments* "--channel") ",")]
      (.join connection channel))
    (.join connection "#hy")))

(defun pubmsg-handler [connection event]
  (let [[arg (get event.arguments 0)]]
    (for [plugin *plugins*]
      (.process plugin connection event arg))))

(defun start[]
  (let [[server (fn[] (if (get *arguments* "--server")
			(get *arguments* "--server") "irc.freenode.net"))]
	[port (fn[] (if (get *arguments* "--port")
		      (get *arguments* "--port") 6667))]
	[nick (fn[] (if (get *arguments* "--nick")
		      (get *arguments* "--nick") "hygdrop"))]
	[bot
	 (irc.bot.SingleServerIRCBot [(, (server) (port))]
				     (nick) "Hy five!")]]
    (.add_global_handler bot.connection "welcome" welcome-handler)
    (.add_global_handler bot.connection "pubmsg" pubmsg-handler)
    (.start bot)))

(if (= __name__ "__main__")
  (start))
