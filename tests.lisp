(in-package :cl-user)

(defpackage :cl-yaclyaml-tests
  (:use :alexandria :cl :cl-yaclyaml :eos :iterate)
  (:export #:run-tests))

(in-package :cl-yaclyaml-tests)

(cl-interpol:enable-interpol-syntax)

(def-suite yaclyaml)
(in-suite yaclyaml)

(defun run-tests ()
  (let ((results (run 'yaclyaml)))
    (eos:explain! results)
    (unless (eos:results-status results)
      (error "Tests failed."))))

(test block-scalar-header
  (is (equal '((:block-indentation-indicator . "3") (:block-chomping-indicator . "-"))
	     (yaclyaml-parse 'c-b-block-header #?"3- #asdf\n")))
  (is (equal '((:block-chomping-indicator . "-") (:block-indentation-indicator . "3"))
	     (yaclyaml-parse 'c-b-block-header #?"-3 #asdf\n")))
  (is (equal '((:block-chomping-indicator . "-") (:block-indentation-indicator . ""))
	     (yaclyaml-parse 'c-b-block-header #?"- #asdf\n")))
  (is (equal '((:block-indentation-indicator . "3") (:block-chomping-indicator . ""))
	     (yaclyaml-parse 'c-b-block-header #?"3 #asdf\n")))
  (is (equal '((:block-chomping-indicator . "") (:block-indentation-indicator . ""))
	     (yaclyaml-parse 'c-b-block-header #?" #asdf\n"))))


(test literal-block-scalars
  (is (equal #?" explicit\n" (yaclyaml-parse 'c-l-block-scalar #?"|2\n  explicit\n")))
  (is (equal #?"text" (yaclyaml-parse 'c-l-block-scalar #?"|-\ntext\n")))
  (is (equal #?"text\n" (yaclyaml-parse 'c-l-block-scalar #?"|\ntext\n")))
  (is (equal #?"text\n" (yaclyaml-parse 'c-l-block-scalar #?"|+\ntext\n")))
  (is (equal #?"\n\nliteral\n \n\ntext\n"
	     (yaclyaml-parse 'c-l-block-scalar
			     #?"|3\n \n  \n  literal\n   \n  \n  text\n\n\n # Comment\n"))))

(test folded-block-scalars
  (is (equal #?"folded text\n" (yaclyaml-parse 'c-l-block-scalar #?">\n folded text\n\n")))
  (is (equal #?"\nfolded line\nnext line\nlast line\n"
	     (yaclyaml-parse 'c-l-block-scalar
			     #?">\n\n folded\n line\n\n next\n line\n\n last\n line\n
# Comment\n")))
  (is (equal #?"foobar\n  * bullet\n  * list\n\n  * lines\n"
	     (yaclyaml-parse 'c-l-block-scalar
			     #?">\n foobar\n   * bullet\n   * list\n\n   * lines\n"))))
      
(test plain-scalars
  (is (equal #?"1st non-empty\n2nd non-empty 3rd non-empty"
	     (yaclyaml-parse 'ns-plain
			     #?"1st non-empty\n\n 2nd non-empty \n\t3rd non-empty"))))

(test double-quoted-scalars
  (is (equal "implicit block key" (let ((cl-yaclyaml::context :block-key))
				    (yaclyaml-parse 'c-double-quoted "\"implicit block key\""))))
  (is (equal "implicit flow key" (let ((cl-yaclyaml::context :flow-key))
				   (yaclyaml-parse 'c-double-quoted "\"implicit flow key\""))))
  (is (equal #?"folded to a space"
	     (yaclyaml-parse 'c-double-quoted
			     #?"\"folded \nto a space\"")))
  (is (equal #?",\nto a line feed"
  	     (yaclyaml-parse 'c-double-quoted
  			     #?"\",\t\n \nto a line feed\"")))
  (is (equal #?"or \t \tnon-content"
  	     (yaclyaml-parse 'c-double-quoted
  			     #?"\"or \t\\\n \\ \tnon-content\"")))
  ;; and all the above components together
  (is (equal #?"folded to a space,\nto a line feed, or \t \tnon-content"
  	     (yaclyaml-parse 'c-double-quoted
  			     #?"\"folded \nto a space,\t\n \nto a line feed, or \t\\\n \\ \tnon-content\"")))
  (is (equal #?" 1st non-empty\n2nd non-empty 3rd non-empty "
  	     (yaclyaml-parse 'c-double-quoted
  			     #?"\" 1st non-empty\n\n 2nd non-empty \n\t3rd non-empty \""))))

(test single-quoted-scalars
  (is (equal "here's to \"quotes\""
	     (yaclyaml-parse 'c-single-quoted "'here''s to \"quotes\"'")))
  (is (equal #?" 1st non-empty\n2nd non-empty 3rd non-empty "
	     (yaclyaml-parse 'c-single-quoted
			     #?"' 1st non-empty\n\n 2nd non-empty \n\t3rd non-empty '"))))
  
  
(test flow-sequence-nodes
  (is (equal '(((:properties (:tag . :non-specific)) (:content . "one"))
	       ((:properties (:tag . :non-specific)) (:content . "two")))
	     (yaclyaml-parse 'c-flow-sequence #?"[ one, two, ]")))
  (is (equal '(((:properties (:tag . :non-specific)) (:content . "three"))
	       ((:properties (:tag . :non-specific)) (:content . "four")))
	     (yaclyaml-parse 'c-flow-sequence #?"[three ,four]")))
  ;; (is (equal '("double quoted" "single quoted" "plain text" ("nested")
  ;; 	       (:mapping ("single" . "pair")))
  ;; 	     (yaclyaml-parse 'c-flow-sequence
  ;; 			     #?"[\n\"double\n quoted\", 'single
  ;;      quoted',\nplain\n text, [ nested ],\nsingle: pair,\n]")))
  )

(test plain-scalars
  (is (equal "::vector"
	     (let ((cl-yaclyaml::context :block-in))
	       (yaclyaml-parse 'ns-plain
			       #?"::vector"))))
  (is (equal "Up, up, and away!"
	     (let ((cl-yaclyaml::context :block-in))
	       (yaclyaml-parse 'ns-plain
			       #?"Up, up, and away!"))))
  (is (equal "-123"
	     (let ((cl-yaclyaml::context :block-in))
	       (yaclyaml-parse 'ns-plain
			       #?"-123"))))
  (is (equal "http://example.com/foo#bar"
	     (let ((cl-yaclyaml::context :block-in))
	       (yaclyaml-parse 'ns-plain
			       #?"http://example.com/foo#bar"))))
  )

(test flow-mapping-nodes
  (is (equal '(:mapping (((:properties (:tag . :non-specific)) (:content . "one"))
			 . ((:properties (:tag . :non-specific)) (:content . "two")))
	       (((:properties (:tag . :non-specific)) (:content . "three"))
			 . ((:properties (:tag . :non-specific)) (:content . "four"))))
	     (yaclyaml-parse 'c-flow-mapping
			     #?"{ one : two , three: four , }")))
  (is (equal '(:mapping (((:properties (:tag . :non-specific)) (:content . "five"))
			 . ((:properties (:tag . :non-specific)) (:content . "six")))
	       (((:properties (:tag . :non-specific)) (:content . "seven"))
			 . ((:properties (:tag . :non-specific)) (:content . "eight"))))
	     (yaclyaml-parse 'c-flow-mapping
			     #?"{five: six,seven : eight}")))
  (is (equal '(:mapping (((:properties (:tag . :non-specific)) (:content . "explicit"))
			 . ((:properties (:tag . :non-specific)) (:content . "entry")))
	       (((:properties (:tag . :non-specific)) (:content . "implicit"))
			 . ((:properties (:tag . :non-specific)) (:content . "entry")))
	       (((:properties (:tag . :non-specific)) (:content . :empty))
		. ((:properties (:tag . :non-specific)) (:content . :empty))))
	     (yaclyaml-parse 'c-flow-mapping
			     #?"{\n? explicit: entry,\nimplicit: entry,\n?\n}")))
  (is (equal '(:mapping (((:properties (:tag . :non-specific)) (:content . "unquoted"))
			 . ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "separate")))
	       (((:properties (:tag . :non-specific)) (:content . "http://foo.com"))
		. ((:properties (:tag . :non-specific)) (:content . :empty)))
	       (((:properties (:tag . :non-specific)) (:content . "omitted value"))
		. ((:properties (:tag . :non-specific)) (:content . :empty)))
	       (((:properties (:tag . :non-specific)) (:content . :empty))
		. ((:properties (:tag . :non-specific)) (:content . "omitted key")))
	       (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ""))
		. ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ""))))
	     (yaclyaml-parse 'c-flow-mapping
			     #?"{\nunquoted : \"separate\",\nhttp://foo.com,
omitted value:,\n: omitted key,'':'',\n}")))
  (is (equal '(:mapping (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "adjacent"))
			 . ((:properties (:tag . :non-specific)) (:content . "value")))
	       (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "readable"))
		. ((:properties (:tag . :non-specific)) (:content . "value")))
	       (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "empty"))
			 . ((:properties (:tag . :non-specific)) (:content . :empty))))
	     (yaclyaml-parse 'c-flow-mapping
			     #?"{\n\"adjacent\":value,\n\"readable\": value,\n\"empty\":\n}")))
  (is (equal '((:mapping (((:properties (:tag . :non-specific)) (:content . "foo"))
			  . ((:properties (:tag . :non-specific)) (:content . "bar")))))
	     (yaclyaml-parse 'c-flow-sequence
			     #?"[\nfoo: bar\n]")))
  (is (equal '((:mapping (((:properties (:tag . :non-specific)) (:content . "foo bar"))
			  . ((:properties (:tag . :non-specific)) (:content . "baz")))))
	     (yaclyaml-parse 'c-flow-sequence
			     #?"[\n? foo\n bar : baz\n]")))
  (is (equal '((:mapping (((:properties (:tag . :non-specific)) (:content . "YAML"))
			  . ((:properties (:tag . :non-specific)) (:content . "separate")))))
	     (yaclyaml-parse 'c-flow-sequence
			     #?"[ YAML : separate ]")))
  (is (equal '((:mapping (((:properties (:tag . :non-specific)) (:content . :empty))
			  . ((:properties (:tag . :non-specific)) (:content . "empty key entry")))))
	     (yaclyaml-parse 'c-flow-sequence
			     #?"[ : empty key entry ]")))
  (is (equal '((:mapping (((:properties (:tag . :non-specific))
			   (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "JSON"))
						  . ((:properties (:tag . :non-specific)) (:content . "like"))))))
			  . ((:properties (:tag . :non-specific)) (:content . "adjacent")))))
	     (yaclyaml-parse 'c-flow-sequence
			     #?"[ {JSON: like}:adjacent ]")))
  )

(test block-sequences
  (is (equal `(((:properties (:tag . :non-specific)) (:content . "foo"))
	       ((:properties (:tag . :non-specific)) (:content . "bar"))
	       ((:properties (:tag . :non-specific)) (:content . "baz")))
	     (yaclyaml-parse 'l+block-sequence #?"- foo\n- bar\n- baz\n")))
  (is (equal `(((:properties (:tag . :non-specific))
		(:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "one"))
				       . ((:properties (:tag . :non-specific)) (:content . "two")))))))
	     (yaclyaml-parse 'l+block-sequence #?"- one: two # compact mapping\n")))
  (is (equal `(:mapping (((:properties (:tag . :non-specific)) (:content . "block sequence"))
			 . ((:properties (:tag . :non-specific))
			    (:content . (((:properties (:tag . :non-specific)) (:content . "one"))
					 ((:properties (:tag . :non-specific))
					  (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "two"))
								 . ((:properties (:tag . :non-specific))
								    (:content . "three")))))))))))
  	     (yaclyaml-parse 'l+block-mapping #?"block sequence:\n  - one\n  - two : three\n")))
  (is (equal `(((:properties (:tag . :non-specific)) (:content . :empty))
	       ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ,#?"block node\n"))
	       ((:properties (:tag . :non-specific))
		(:content . (((:properties (:tag . :non-specific)) (:content . "one"))
			     ((:properties (:tag . :non-specific)) (:content . "two")))))
	       ((:properties (:tag . :non-specific))
		(:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "one"))
				       . ((:properties (:tag . :non-specific)) (:content . "two")))))))
  	     (yaclyaml-parse 'l+block-sequence
  			     #?"- # Empty\n- |\n block node\n- - one # Compact\n  - two # sequence\n- one: two\n")))
  )

(test block-mappings
  (is (equal `(:mapping (((:properties (:tag . :non-specific)) (:content . "block mapping"))
			 . ((:properties (:tag . :non-specific))
			    (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "key"))
						   . ((:properties (:tag . :non-specific)) (:content . "value"))))))))
	     (yaclyaml-parse 'l+block-mapping #?"block mapping:\n key: value\n")))
  (is (equal `(:mapping (((:properties (:tag . :non-specific)) (:content . "explicit key"))
			 . ((:properties (:tag . :non-specific)) (:content . :empty))))
	     (yaclyaml-parse 'l+block-mapping #?"? explicit key # Empty value\n")))
  (is (equal `(:mapping (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ,#?"block key\n"))
			 . ((:properties (:tag . :non-specific)) (:content . "flow value"))))
	     (yaclyaml-parse 'l+block-mapping #?"? |\n  block key\n: flow value\n")))
  (is (equal `(:mapping (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ,#?"block key\n"))
			 . ((:properties (:tag . :non-specific))
			    (:content . (((:properties (:tag . :non-specific)) (:content . "one"))
					 ((:properties (:tag . :non-specific)) (:content . "two")))))))
	     (yaclyaml-parse 'l+block-mapping #?"? |\n  block key\n: - one # Explicit compact\n  - two # block value\n")))
  (is (equal `(:mapping (((:properties (:tag . :non-specific)) (:content . "plain key"))
			 . ((:properties (:tag . :non-specific)) (:content . "in-line value")))
			(((:properties (:tag . :non-specific)) (:content . :empty))
			 . ((:properties (:tag . :non-specific)) (:content . :empty)))
			(((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "quoted key"))
			 . ((:properties (:tag . :non-specific))
			    (:content . (((:properties (:tag . :non-specific)) (:content . "entry")))))))
	     (yaclyaml-parse 'l+block-mapping #?"plain key: in-line value\n: # Both empty\n\"quoted key\":\n- entry\n")))
  )

(test compact-block-mappings
  (is (equal `(((:properties (:tag . :non-specific))
		(:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "sun"))
				       . ((:properties (:tag . :non-specific)) (:content . "yellow"))))))
	       ((:properties (:tag . :non-specific))
		(:content . (:mapping (((:properties (:tag . :non-specific))
					(:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "earth"))
							       . ((:properties (:tag . :non-specific))
								  (:content . "blue"))))))
				       . ((:properties (:tag . :non-specific))
					  (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "moon"))
								 . ((:properties (:tag . :non-specific))
								    (:content . "white")))))))))))
	     (yaclyaml-parse 'l+block-sequence #?"- sun: yellow\n- ? earth: blue\n  : moon: white\n"))))

(test node-properties
  (is (equal `(:mapping (((:properties (:tag . "tag:yaml.org,2002:str") (:anchor . "a1")) (:content . "foo"))
			 . ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "bar")))
			(((:properties (:tag . :non-specific) (:anchor . "a2")) (:content . "baz"))
			 . (:alias . "a1")))
	     (yaclyaml-parse 'l+block-mapping #?"!!str &a1 \"foo\":\n  !!str bar\n&a2 baz : *a1\n"))))

(test bare-document  
  (is (equal '((:document ((:properties (:tag . :non-specific)) (:content . "Bare document"))) 14)
	     (multiple-value-list (yaclyaml-parse 'l-bare-document
						  #?"Bare document\n...\n# No document\n...\n|\n%!PS-Adobe-2.0 # Not the first line\n" :junk-allowed t))))
  ;; (is (equal '("Bare document" 14)
  ;; 	     (multiple-value-list (yaclyaml-parse 'l-bare-document
  ;; 						  #?"# No document\n...\n|\n%!PS-Adobe-2.0 # Not the first line\n" :junk-allowed t))))
  (is (equal `(:document ((:properties (:tag . "tag:yaml.org,2002:str"))
			  (:content . ,#?"%!PS-Adobe-2.0 # Not the first line\n")))
	     (yaclyaml-parse 'l-bare-document
			     #?"|\n%!PS-Adobe-2.0 # Not the first line\n")))
  )

(test explicit-documents
  (is (equal '(:document ((:properties (:tag . :non-specific))
			  (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "matches %"))
						 . ((:properties (:tag . :non-specific)) (:content . "20")))))))
	     (yaclyaml-parse 'l-explicit-document
			     #?"---\n{ matches\n% : 20 }\n")))
  ;; (is (equal ""
  ;; 	     (yaclyaml-parse 'l-explicit-document
  ;; 			     #?"---\n# Empty\n")))
  )

(test directive-documents
  (is (equal `(:document ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . ,#?"%!PS-Adobe-2.0\n")))
	     (yaclyaml-parse 'l-directive-document
			     #?"%YAML 1.2\n--- |\n%!PS-Adobe-2.0\n")))
  ;; (is (equal #?""
  ;; 	     (yaclyaml-parse 'l-directive-document
  ;; 			     #?"%YAML 1.2\n---# Empty\n")))
  )


(test yaml-stream
  (is (equal '((:document ((:properties (:tag . :non-specific)) (:content . "Document")))
	       (:document ((:properties (:tag . :non-specific)) (:content . "another")))
	       (:document ((:properties (:tag . :non-specific))
			   (:content . (:mapping (((:properties (:tag . :non-specific)) (:content . "matches %"))
						  . ((:properties (:tag . :non-specific)) (:content . "20"))))))))
	     (yaclyaml-parse 'l-yaml-stream
			     #?"Document\n---\nanother\n...\n%YAML 1.2\n---\nmatches %: 20")))
  )
  
				  
;; (test flow-nodes
;;   (is (equal '((:mapping ("YAML" . "separate"))) (yaclyaml-parse 'ns-flow-node #?"!!str \"a\"")))
;;   )
  

(test tag-shorthands
  (is (equal '((:document ((:properties (:tag . :non-specific))
			   (:content . (((:properties (:tag . "!local")) (:content . "foo"))
					((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "bar"))
					((:properties (:tag . "tag:example.com,2000:app/tag%21")) (:content . "baz")))))))
	     (yaclyaml-parse 'l-yaml-stream #?"%TAG !e! tag:example.com,2000:app/\n---
- !local foo\n- !!str bar\n- !e!tag%21 baz")))
  )

(test construction-of-representation-graph
  ;; FIXME: for now such a lame check will suffice, I dunno how to check shared structured-ness easily
  (is (equal `(:mapping (((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "foo"))
			 . ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "bar")))
			(((:properties) (:content . "baz"))
			 . ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "foo"))))
	     (ncompose-representation-graph
	      (copy-tree `(:mapping (((:properties (:tag . "tag:yaml.org,2002:str") (:anchor . "a1")) (:content . "foo"))
				     . ((:properties (:tag . "tag:yaml.org,2002:str")) (:content . "bar")))
				    (((:properties (:anchor . "a2")) (:content . "baz"))
				     . (:alias . "a1"))))))))


;;; Generating native language structures from representation graph

;; (defmacro with-flat-nodes ((from to) &body body)
;;   (iter (for i from from to to)
;; 	(collect `(,(sb-int:symbolicate "NODE" (format nil "~a" i))
;; 		    '((:properties) (:content . ,(format nil "~a" i)))) into res)
;; 	(finally (return `(let ,res ,@body)))))

;; (defmacro with-cons-nodes ((from to) &body body)
;;   (iter (for i from from to to)
;; 	(collect `(,(sb-int:symbolicate "CONS-NODE" (format nil "~a" i))
;; 		    (list (list :properties) (list :content))) into res)
;; 	(finally (return `(let ,res ,@body)))))

;; (defmacro link-nodes (which where)
;;   `(push ,which (cdr (assoc :content ,where))))

;; (defun mk-node (num)
;;   (sb-int:symbolicate "NODE" (format nil "~a" num)))

;; (defun mk-cons-node (num)
;;   (sb-int:symbolicate "CONS-NODE" (format nil "~a" num)))


;; (test find-parents
;;   (with-flat-nodes (1 5)
;;     (with-cons-nodes (1 5)
;;       (is (equal
;; 	   (let ((res (make-hash-table :test #'eq)))
;; 	     (setf (gethash cons-node2 res) (list cons-node1)
;; 		   (gethash node1 res) (list cons-node1)
;; 		   (gethash cons-node3 res) (list cons-node2)
;; 		   (gethash node2 res) (list cons-node2)
;; 		   (gethash cons-node4 res) (list cons-node3)
;; 		   (gethash node3 res) (list cons-node3)
;; 		   (gethash cons-node5 res) (list cons-node4)
;; 		   (gethash node4 res) (list cons-node4)
;; 		   (gethash node5 res) (list cons-node5))
;; 	     res)
;; 	   (macrolet ((with-simple-chain ((from to) &body body)
;; 			(iter (for i from from below to)
;; 			      (collect `(link-nodes ,(mk-node (1+ i))
;; 						    ,(mk-cons-node (1+ i))) into res)
;; 			      (collect `(link-nodes ,(mk-cons-node (1+ i))
;; 						    ,(mk-cons-node i)) into res)
;; 			      (finally (return
;; 					 `(progn (link-nodes ,(mk-node from)
;; 							     ,(mk-cons-node from))
;; 						 ,@res
;; 						 (let ((chain ,(mk-cons-node from)))
;; 						   ,@body)))))))
;; 	     (with-simple-chain (1 5)
;; 	       (cl-yaclyaml::find-parents chain))))))))
	     
	
(test scalar-construction-failsafe
  (is (equal '((:content . "asdf") (:tag . :non-specific))
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "asdf")) :schema :failsafe)))
  (is (equal "asdf"
	     (construct '((:properties . ((:tag . "tag:yaml.org,2002:str"))) (:content . "asdf")) :schema :failsafe)))
  (is (equal '((:content . :empty) (:tag . "tag:yaml.org,2002:null"))
	     (construct '((:properties . ((:tag . "tag:yaml.org,2002:null"))) (:content . :empty)) :schema :failsafe))))
  
  
(test scalar-construction-json
  (signals (error "JSON impication of scalar didn't signal an error.")
      (construct '((:properties . ((:tag . :non-specific))) (:content . "asdf")) :schema :json))
  (is (equal "asdf"
	     (construct '((:properties . ((:tag . "tag:yaml.org,2002:str"))) (:content . "asdf")) :schema :json)))
  (is (equal 123
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "123")) :schema :json)))
  (is (equal -3.14
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "-3.14")) :schema :json)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . :empty)) :schema :json)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "null")) :schema :json))))
  

(test scalar-construction-core
  (is (equal "asdf"
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "asdf")) :schema :core)))
  (is (equal "asdf"
	     (construct '((:properties . ((:tag . "tag:yaml.org,2002:str"))) (:content . "asdf")) :schema :core)))
  (is (equal 123
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "123")) :schema :core)))
  (is (equal -3.14
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "-3.14")) :schema :core)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . :empty)) :schema :core)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "null")) :schema :core)))
  (is (equal ""
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "")) :schema :core)))
  (is (equal t
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "true")) :schema :core)))
  (is (equal t
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "True")) :schema :core)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "false")) :schema :core)))
  (is (equal nil
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "FALSE")) :schema :core)))
  (is (equal 0
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "0")) :schema :core)))
  (is (equal 7
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "0o7")) :schema :core)))
  (is (equal 58
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "0x3A")) :schema :core)))
  (is (equal -19
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "-19")) :schema :core)))
  (is (equalp 0
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "0.")) :schema :core)))
  (is (equalp 0
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "-0.0")) :schema :core)))
  (is (equal 0.5
	     (construct '((:properties . ((:tag . :non-specific))) (:content . ".5")) :schema :core)))
  (is (equalp 12000
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "+12e03")) :schema :core)))
  (is (equalp -200000
	     (construct '((:properties . ((:tag . :non-specific))) (:content . "-2E+05")) :schema :core)))
  (is (equalp :nan
	      (construct '((:properties . ((:tag . :non-specific))) (:content . ".NAN")) :schema :core)))
  (is (equalp :infinity
	      (construct '((:properties . ((:tag . :non-specific))) (:content . ".Inf")) :schema :core)))
  )

(test simple-sequences
  (is (equal '((:document ("foo" "bar" "baz")))
	     (yaml-load #?"- foo\n- bar\n- baz\n")))
  (is (equal '((:document ((:content . (((:content . "foo") (:tag . :non-specific))
					((:content . "bar") (:tag . :non-specific))
					((:content . "baz") (:tag . :non-specific))))
			   (:tag . :non-specific))))
	     (yaml-load #?"- foo\n- bar\n- baz\n" :schema :failsafe)))
  )

(test simple-mappings
  (is (equal '(("earth" . "green") ("moon" . "blue") ("sun" . "gold"))
	     (sort (hash->assoc (cadar (yaml-load #?"sun : gold\nearth : green\nmoon : blue")))
		   #'string< :key #'car))))
  
