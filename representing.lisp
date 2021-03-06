;;;; This file is one of components of CL-YACLYAML system, licenced under GPL, see COPYING for details

(in-package #:cl-yaclyaml)

;;; Representing native structures as sequences, mappings and scalars with tags.

(defparameter tag-prefix "tag:yaml.org,2002:")

(defparameter lisp-tag-prefix "tag:lisp,2013:")

(defparameter cons-maps-as-maps nil "If T, represent alists and plists as mappings, not as sequences")

(defun represent-scalar (x)
  (flet ((frob (type obj &optional (prefix tag-prefix))
	   ;; FIXME: maybe FORMAT-aesthetic on the next line is not what we really want?
	   (values `((:properties . ((:tag . ,(strcat prefix type)))) (:content . ,(format nil "~a" obj))) t)))
    (typecase x
      (integer (frob "int" x))
      (float (frob "float" x))
      (string (frob "str" x))
      (symbol (cond ((eq x t) (frob "bool" "true"))
		    ((eq x nil) (frob "null" "null"))
		    ((keywordp x) (frob "keyword" x lisp-tag-prefix))
		    (t (frob "symbol" x lisp-tag-prefix))))
      (t (values nil nil)))))

(defun represent-mapping (x)
  (declare (special representation-cache))
  (declare (special visited-cache))
  (declare (special initialization-callbacks))
  (let (result last-cons)
    (macrolet! ((collect-result (o!-key o!-val)
				`(if result
				     (progn (setf (cdr last-cons) (list `(,,o!-key . ,,o!-val)))
					    (setf last-cons (cdr last-cons)))
				     (progn (setf result (list `(,,o!-key . ,,o!-val)))
					    (setf last-cons result))))
		(frob ()
		      `(progn
			 (if (gethash key visited-cache)
			     (if (gethash val visited-cache)
				 (progn (collect-result nil nil)
					(let (initialized-key
					      initialized-val
					      (encap-key key)
					      (encap-val val)
					      (encap-last-cons last-cons))
					  (flet ((frob-key ()
						   (if initialized-val
						       (setf (caar encap-last-cons) initialized-key
							     (cdar encap-last-cons) initialized-val)
						       (setf initialized-key (gethash encap-key representation-cache))))
						 (frob-val ()
						   (if initialized-key
						       (setf (caar encap-last-cons) initialized-key
							     (cdar encap-last-cons) initialized-val)
						       (setf initialized-val (gethash encap-val representation-cache)))))
					    (push #'frob-key (gethash key initialization-callbacks))
					    (push #'frob-val (gethash val initialization-callbacks)))))
				 (progn (collect-result nil (%represent-node val))
					(push (let ((encap-key key)
						    (encap-last-cons last-cons))
						(lambda ()
						  (setf (caar encap-last-cons)
							(gethash encap-key representation-cache))))
					      (gethash key initialization-callbacks))))
			     (if (gethash val visited-cache)
				 (progn (collect-result (%represent-node key) nil)
					(push (let ((encap-val val)
						    (encap-last-cons last-cons))
						(lambda ()
						  (setf (cdar encap-last-cons)
							(gethash encap-val representation-cache))))
					      (gethash val initialization-callbacks)))
				 (collect-result (%represent-node key) (%represent-node  val))))
			 (collect `(,(%represent-node key) . ,(%represent-node val)) into res)
			 (finally (return (values `((:properties . ((:tag . ,(strcat tag-prefix "map"))))
						    (:content . (:mapping ,.result)))
						  t))))))
      (typecase x
	(hash-table (if (eq (hash-table-test x) 'equal)
			(iter (for (key val) in-hashtable x)
			      (frob))
			(error "Hash-tables with test-functions other than EQUAL cannot be dumped now.")))
	(cons (cond ((and cons-maps-as-maps (alist-p x))
		     (iter (for (key . val) in x)
			   (frob)))
		    ((and cons-maps-as-maps (plist-p x))
		     (iter (for key in x by #'cddr)
			   (for val in (cdr x) by #'cddr)
			   (frob)))
		    (t (values nil nil))))
	(t (values nil nil))))))

(defun represent-sequence (x)
  (declare (special representation-cache))
  (declare (special visited-cache))
  (declare (special initialization-callbacks))
  (let (result last-cons)
    (macrolet! ((collect-result (o!-node)
				`(if result
				     (progn (setf (cdr last-cons) (list ,o!-node))
					    (setf last-cons (cdr last-cons)))
				     (progn (setf result (list ,o!-node))
					    (setf last-cons result))))
		(frob ()
		      `(progn (if (gethash subnode visited-cache)
				  (progn (collect-result nil)
					 (push (let ((encap-subnode subnode)
						     (encap-last-cons last-cons))
						 (lambda ()
						   (setf (car encap-last-cons)
							 (gethash encap-subnode representation-cache))))
					       (gethash subnode initialization-callbacks)))
				  (collect-result (%represent-node subnode)))
			      (finally (return (values `((:properties . ((:tag . ,(strcat tag-prefix "seq"))))
							 (:content . ,result))
						       t))))))
      (typecase x
	(cons (iter (for subnode in x)
		    (frob)))
	((and array (not string)) (iter (for subnode in-vector x)
					(frob)))
	(t (values nil nil))))))

(defun %represent-node (x)
  (declare (special representation-cache))
  (declare (special initialization-callbacks))
  (declare (special visited-cache))
  (setf (gethash x visited-cache) t)
  (a:acond-got ((gethash x representation-cache) it)
	       (t (let ((res (a:acond-got ((represent-mapping x) it)
					  ((represent-sequence x) it)
					  ((represent-scalar x) it)
					  (t (error "Failed to represent object: ~a" x)))))
		    (setf (gethash x representation-cache) res)
		    (iter (for callback in (gethash x initialization-callbacks))
			  (funcall callback))
		    (remhash x initialization-callbacks)
		    res))))

(defun represent-node (x)
  (let ((representation-cache (make-hash-table :test #'eq))
	(visited-cache (make-hash-table :test #'eq))
	(initialization-callbacks (make-hash-table :test #'eq)))
    (declare (special representation-cache))
    (declare (special visited-cache))
    (declare (special initialization-callbacks))
    (%represent-node x)))

(defun plist-p (x)
  "Returns T if X is a property list in a narrow sense - all odd elements are non-duplicating symbols."
  nil)

(defun alist-p (x)
  "Returns T if X is an association list in a narrow sense - all CAR's of assocs are non-duplicating symbols."
  nil)


