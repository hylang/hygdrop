(import irc.bot)
(import ast)
(import sandbox)
(import hy.importer)
(import hy.compiler)
(import __builtin__)
(import StringIO)
(import sys)
(import time)
(import re)
(import [functools [partial]])
(import requests)

(defn on-welcome [connection event]
  (.join connection "#hy"))

(defn dump-exception [e]
  (.write sys.stderr (str e))
  (.write sys.stderr "\n")
  (.flush sys.stderr))

(defn pretty-print-issue [connection target arg]
  (setv (, project repo issue) arg)
  (if (not project) (setv project "hylang"))
  (if (not repo) (setv repo "hy"))
  (let [[api-url (+ "https://api.github.com/repos/" project "/" repo "/issues/" issue)]
        [api-result (requests.get api-url)]
        [api-json (.json api-result)]]
    (if (= (getattr api-result "status_code") 200)
      (do
        (setv title (get api-json "title"))
        (setv status (get api-json "state"))
        (setv issue-url (get api-json "html_url"))
        (defn get_name [x] (get x "name"))
        (setv labels (.join "|" (map get_name (get api-json "labels"))))
        (setv author (get (get api-json "user") "login"))
        (if (get (get api-json "pull_request") "html_url")
          (setv message [(+ "Pull Request #" issue)])
          (setv message [(+ "Issue #" issue)]))
        (.extend message [
          "on"
          (+ project "/" repo)
          "by"
          (+ author ":")
          title
          (+ "(" status ")")])
        (if labels (setv please-hy-don-t-return-when-i (.append message (+ "[" labels "]"))))
        (.append message (+ "<" issue-url ">"))
        (.notice connection target (.join " " message))))))

(defn pretty-print-commit [connection target arg]
  (setv (, project repo commit) arg)
  (if (not project) (setv project "hylang"))
  (if (not repo) (setv repo "hy"))
  (let [[api-url (+ "https://api.github.com/repos/" project "/" repo "/commits/" commit)]
        [api-result (requests.get api-url)]
        [api-json (.json api-result)]]
    (if (= (getattr api-result "status_code") 200)
      (do
        (setv commit-json (get api-json "commit"))
        (setv title (get (.splitlines (get commit-json "message")) 0))
        (setv author (get (get commit-json "author") "name"))
        (setv commit-url (get api-json "html_url"))
        (setv sha (get api-json "sha"))
        (setv message [
          "Commit"
          (slice sha 0 7)
          "on"
          (+ project "/" repo)
          "by"
          (+ author ":")
          title
          (+ "<" commit-url ">")])
        (.notice connection target (.join " " message))))))

(defn on-pubmsg [connection event]
  (let [[arg (get event.arguments 0)]
        [code null]
        [bsandbox null]
        [sandbox-config null]
        [compiled-code null]]
    (map (partial pretty-print-issue connection event.target)
         (re.findall "(?:(?:(?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?#(?P<issue>\\d+)" arg))
    (map (partial pretty-print-commit connection event.target)
         (re.findall "(?:(?:(?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?@(?P<commit>[a-f0-9]+)" arg))
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
