(import requests
	re
	[functools [partial lru_cache]])

(with-decorator (kwapply (lru_cache) {"maxsize" 256})
  (defun get-github-issue [connection target issue
			   &optional [project "hylang"] [repo "hy"]
			   [dry-run False]]
    (let [[api-url (.format "https://api.github.com/repos/{}/{}/issues/{}"
			    project repo issue)]
	  [api-result (.get requests api-url)]
	  [api-json (.json api-result)]]
      (if (= (getattr api-result "status_code") 200)
	(let [[title (get api-json "title")]
					   [status (get api-json "state")]
	      [issue-url (get api-json "html_url")]
					   [get-name (fn [x] (get x "name"))]
	      [labels (.join "|" (map get-name (get api-json "labels")))]
	      [author (get (get api-json "user") "login")]
	      [message (list)]]
	  (if (get (get api-json "pull_request") "html_url")
	    (.extend message [(+ "Pull Request #" issue)])
	    (.extend message [(+ "Issue #" issue)]))
	  (.extend message ["on" (+ project "/" repo)
				 "by" (+ author ":") title
				 (+ "(" status ")")])
	  (if labels
	    (setv please-hy-don-t-return-when-i
		  (.append message (+ "[" labels "]"))))
	  (.append message (+ "<" issue-url ">"))
	  (if dry-run
	    (.join " " message)
	    (.notice connection target (.join " " message))))))))

(with-decorator (kwapply (lru_cache) {"maxsize" 256})
  (defun get-github-commit [connection target commit
			    &optional [project "hylang"] [repo "hy"]
			    [dry-run False]]
    (let [[api-url (.format "https://api.github.com/repos/{}/{}/commits/{}"
			    project repo commit)]
	  [api-result (.get requests api-url)]
	  [api-json (.json api-result)]]
      (if (= (getattr api-result "status_code") 200)
	(let [[commit-json (get api-json "commit")]
	      
	      [title (get (.splitlines (get commit-json "message")) 0)]
	      [author (get (get commit-json "author") "name")]
	      [commit-url (get api-json "html_url")]
	      [shasum (get api-json "sha")]
	      [message ["Commit" (slice shasum 0 7) "on"
				 (+ project "/" repo)
				 "by" (+ author ":") title
				 (+ "<" commit-url ">")]]]
	  (if dry-run
	    (.join " " message)
	    (.notice connection target (.join " " message))))))))

(with-decorator (kwapply (lru_cache) {"maxsize" 256})
  (defun get-core-members [connection target &optional [project "hylang"]
			   [dry-run False]]
    (let [[api-url (.format "https://api.github.com/orgs/{}/members"
			    project)]
	  [api-result (.get requests api-url)]
	  [api-json (.json api-result)]
	  [message (list)]]
      (if (= (getattr api-result "status_code") 200)
	(do
	 (foreach [dev api-json]
	   (do
	    (setv dev-result (.get requests
				   (.format "https://api.github.com/users/{}"
					    (get dev "login"))))
	    (if (= (getattr dev-result "status_code") 200)
	      ;; special case handling specifically for khinsen, his
	      ;; null name breaks our code :(
	      (setv don-t-return-damit
		    (.extend message [(if (not (get (.json dev-result) "name"))
					(get dev "login")
					(get (.json dev-result) "name"))])))))))
      (if dry-run
	(+ "Core Team consists of: " (.join ", " message))
	(.notice connection target (+ "Core Team consists of: "
				      (.join ", " message)))))))

(defun handle-github-msg [github-fn github-msg
			  &optional [dry-run False]]
  (let [[project (.group github-msg "project")]
	[repo (.group github-msg "repo")]
	[query (.group github-msg "query")]]
    (if (not project) (setv project "hylang"))
    (if (not repo) (setv repo "hy"))
    (kwapply (github-fn query) {"project" project "repo" repo
					  "dry_run" (if dry-run True False)})))

(defun process[connection event message]
  (let [[issue-msg (re.search "(((?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?#(?P<query>\\d+)" message)]
	[commit-msg (re.search "(((?P<project>[a-zA-Z0-9._-]+)/)?(?P<repo>[a-zA-Z0-9._-]+))?@(?P<query>[a-f0-9]+)" message)]
	[issue-fn (partial get-github-issue connection event.target)]
	[commit-fn (partial get-github-issue connection event.target)]]
    (if issue-msg
      (handle-github-msg issue-fn issue-msg))
    (if commit-msg
      (handle-github-msg commit-fn commit-msg))    
    (if (not (= (re.search
		 "(?:(.*core team.*members?.*|.*members?.*core team.*))"
		 message) null))
      (get-core-members connection event.target))))
