;;;; This file is one of components of CL-YACLYAML system, licenced under GPL, see COPYING for details

(in-package #:cl-yaclyaml)

;;; Generating native structures from the nodes

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter visited-nodes `(,(make-hash-table :test #'eq)))
  (defparameter converted-nodes (make-hash-table :test #'eq))
  (defparameter scalar-converters (make-hash-table :test #'equal))
  (defparameter sequence-converters (make-hash-table :test #'equal))
  (defparameter mapping-converters (make-hash-table :test #'equal))
  (defparameter initialization-callbacks (make-hash-table :test #'eq)))

(defmacro with-fresh-visited-level (&body body)
  `(let ((visited-nodes `(,(make-hash-table :test #'eq) ,visited-nodes)))
     ,@body))

(defmacro mark-node-as-visited (node)
  (setf (gethash node (car visited-nodes)) t))

(defun scalar-p (node)
  (atom (cdr (assoc :content node))))

(defun mapping-p (node)
  (equal :mapping (car (cdr (assoc :content node)))))

(defun converted-p (node)
  (gethash node converted-nodes))

(defun visited-p (node)
  (iter (for level in visited-nodes)
	(if (gethash node level)
	    (return t))
	(finally (return nil))))

(defun install-scalar-converter (tag converter)
  (setf (gethash tag scalar-converters) converter))
(defun install-sequence-converter (tag converter)
  (setf (gethash tag sequence-converters) converter))
(defun install-mapping-converter (tag converter)
  (setf (gethash tag mapping-converters) converter))


(defun trivial-scalar-converter (content)
  (copy-seq content))

(defun convert-scalar (content tag)
  (let ((converter (gethash tag scalar-converters)))
    (if converter
	(funcall converter content)
	;; fallback behaviour is to convert nothing
	;; yet, we strip unneeded :PROPERTIES list, leaving only :TAG property.
	`((:content . ,content) (:tag . ,tag)))))

(defun convert-sequence (content tag)
  (let ((converter (gethash tag sequence-converters)))
    (if converter
	(funcall converter content)
	`((:content . ,(convert-sequence-to-list content)) (:tag . ,tag)))))

(defun convert-mapping (content tag)
  (let ((converter (gethash tag mapping-converters)))
    (if converter
	(funcall converter content)
	`((:content . ,(convert-mapping-to-hashtable content)) (:tag . ,tag)))))

(defun convert-sequence-to-list (nodes)
  (let (result last-cons)
    (macrolet! ((collect-result (o!-node)
		 `(if result
		      (progn (setf (cdr last-cons) (list ,o!-node))
			     (setf last-cons (cdr last-cons)))
		      (progn (setf result (list ,o!-node))
			     (setf last-cons result)))))
      (iter (for subnode in nodes)
	    (multiple-value-bind (it got) (gethash subnode converted-nodes)
	      (if got
		  (collect-result it)
		  (if (scalar-p subnode)
		      (collect-result (convert-scalar! subnode))
		      (progn (collect-result nil)
			     (push (lambda ()
				     (setf (car last-cons) (gethash subnode converted-nodes)))
				   (gethash subnode initialization-callbacks)))))))
      result)))

(defun convert-mapping-to-hashtable (content)
  (let ((result (make-hash-table :test #'equal)))
    (iter (for (key . val) in (cdr content)) ; CAR of content is :MAPPING keyword
	  (multiple-value-bind (conv-key got-key) (gethash key converted-nodes)
	    (multiple-value-bind (conv-val got-val) (gethash val converted-nodes)
	      (if got-key
		  (if got-val
		      (setf (gethash conv-key result) conv-val)
		      (push (lambda ()
			      (setf (gethash conv-key result)
				    (gethash val converted-nodes)))
			    (gethash val initialization-callbacks)))
		  (if got-val
		      (push (lambda ()
			      (setf (gethash got-key result)
				    (gethash val converted-nodes)))
			    (gethash key initialization-callbacks))
		      (let (key-installed val-installed)
			(flet ((frob-key ()
				 (if val-installed
				     (setf (gethash key-installed result) val-installed)
				     (setf key-installed (gethash key converted-nodes))))
			       (frob-val ()
				 (if key-installed
				     (setf (gethash key-installed result) val-installed)
				     (setf val-installed (gethash val converted-nodes)))))
			  (push #'frob-key (gethash key initialization-callbacks))
			  (push #'frob-val (gethash val initialization-callbacks)))))
		  ))))
    result))
  

(defmacro with-failsafe-schema (&body body)
  `(let ((scalar-converters (make-hash-table :test #'equal))
	 (sequence-converters (make-hash-table :test #'equal))
	 (mapping-converters (make-hash-table :test #'equal)))
     (install-scalar-converter "tag:yaml.org,2002:str" #'trivial-scalar-converter)
     (install-sequence-converter "tag:yaml.org,2002:seq" #'convert-sequence-to-list)
     (install-mapping-converter "tag:yaml.org,2002:map" #'convert-mapping-to-hashtable)
     ,@body))

(defmacro with-json-schema (&body body)
  `(with-failsafe-schema
     (install-scalar-converter "tag:yaml.org,2002:null" (lambda (content)
							  (declare (ignore content))))
     (install-scalar-converter "tag:yaml.org,2002:bool"
			       (lambda (content)
				 (if (equal content "true")
				     t
				     (if (equal content "false")
					 nil
					 (error "Expected 'true' or 'false' but got ~a." content)))))
     (install-scalar-converter "tag:yaml.org,2002:int"
			       (lambda (content)
				 (parse-integer content)))
     (install-scalar-converter "tag:yaml.org,2002:float"
			       (lambda (content)
				 (parse-real-number content)))
     (install-scalar-converter :non-specific
			       (lambda (content)
				 (cond ((or (equal content :empty)
					    (all-matches "^null$" content))
					(convert-scalar content "tag:yaml.org,2002:null"))
				       ((all-matches "^(true|false)$" content) (convert-scalar content
											       "tag:yaml.org,2002:bool"))
				       ((all-matches "^-?(0|[1-9][0-9]*)$" content) (convert-scalar content
											       "tag:yaml.org,2002:int"))
				       ((all-matches "^-?(0|[1-9][0-9]*)(\\.[0-9]*)?([eE][-+]?[0-9]+)?$" content)
					(convert-scalar content "tag:yaml.org,2002:float"))
				       (t (error "Could not resolve scalar: ~a" content)))))
     (install-sequence-converter :non-specific
				 (lambda (content)
				   (convert-sequence content "tag:yaml.org,2002:seq"))) 
     (install-mapping-converter :non-specific
				(lambda (content)
				  (convert-mapping content "tag:yaml.org,2002:map"))) 
     ,@body))


(defmacro with-core-schema (&body body)
  `(with-json-schema
     (install-scalar-converter :non-specific
			       (lambda (content)
				 (cond ((or (equal content :empty)
					    (all-matches "^(null|Null|NULL|~)$" content))
					(convert-scalar content "tag:yaml.org,2002:null"))
				       ((all-matches "^(true|True|TRUE|false|False|FALSE)$" content)
					(convert-scalar (string-downcase content) "tag:yaml.org,2002:bool"))
				       ((all-matches "^[-+]?(0|[1-9][0-9]*)$" content)
					(convert-scalar content "tag:yaml.org,2002:int"))
				       ((all-matches "^0o[0-7]+$" content)
					(parse-integer content :start 2 :radix 8))
				       ((all-matches "^0x[0-9a-fA-F]+$" content)
					(parse-integer content :start 2 :radix 16))
				       ((all-matches "^[-+]?(\\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$" content)
					(convert-scalar content "tag:yaml.org,2002:float"))
				       ((all-matches "^[-+]?(\\.inf|\\.Inf|\\.INF)$" content)
					:infinity)
				       ((all-matches "^[-+]?(\\.nan|\\.NaN|\\.NAN)$" content)
					:nan)
				       (t (convert-scalar content "tag:yaml.org,2002:str")))))
     ,@body))

(defmacro define-bang-convert (name converter-name)
  `(defun ,name (node)
     (multiple-value-bind (it got) (gethash node converted-nodes)
       (if (not got)
	   (let* ((content (cdr (assoc :content node)))
		  (properties (cdr (assoc :properties node)))
		  (tag (cdr (assoc :tag properties))))
	     (setf (gethash node converted-nodes)
		   (,converter-name content tag))
	     (iter (for callback in
			(gethash node initialization-callbacks))
		   (funcall callback)))
	   it))))
(define-bang-convert convert-scalar! convert-scalar)
(define-bang-convert convert-sequence! convert-sequence)
(define-bang-convert convert-mapping! convert-mapping)

(defun %depth-first-traverse (cur-level &optional (level 0))
  (macrolet ((add-node-if-not-visited (node)
	       `(when (not (visited-p ,node))
		  (mark-node-as-visited ,node)
		  (push ,node next-level))))
    (let (next-level)
      (iter (for node in cur-level)
	    (cond ((scalar-p node) nil)
		  ((mapping-p node) (iter (for (key . val) in (cdr (cdr (assoc :content node))))
					  (add-node-if-not-visited key)
					  (add-node-if-not-visited val)))
		  (t (iter (for subnode in (cdr (assoc :content node)))
			   (add-node-if-not-visited subnode))))
	    (finally (if next-level
			 (%depth-first-traverse next-level (1+ level)))
		     (iter (for node in cur-level)
			   (when (not (gethash node converted-nodes))
			     (let* ((content (cdr (assoc :content node)))
				    (properties (cdr (assoc :properties node)))
				    (tag (cdr (assoc :tag properties))))
			       (setf (gethash node converted-nodes)
				     (cond ((scalar-p node)
					    (convert-scalar content tag))
					   ((mapping-p node)
					    (convert-mapping content tag))
					   (t (convert-sequence content tag)))))
			     (iter (for callback in
					(gethash node initialization-callbacks))
				   (funcall callback))))
		     )))))

(defun construct (representation-graph &key (schema :core))
  (let ((visited-nodes `(,(make-hash-table :test #'eq)))
	(converted-nodes (make-hash-table :test #'eq))
	(initialization-callbacks (make-hash-table :test #'eq)))
    (case schema
      (:failsafe (with-failsafe-schema
		   (%depth-first-traverse `(,representation-graph))))
      (:json (with-json-schema
	       (%depth-first-traverse `(,representation-graph))))
      (:core (with-core-schema
	       (%depth-first-traverse `(,representation-graph)))))
    (gethash representation-graph converted-nodes)))
  
(defun yaml-load (string &key (schema :core))
  (iter (for (document content) in (ncompose-representation-graph (yaclyaml-parse 'l-yaml-stream string)))
	(collect `(:document ,(construct content :schema schema)))))


