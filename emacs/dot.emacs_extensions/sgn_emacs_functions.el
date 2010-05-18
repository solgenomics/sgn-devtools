
;;;; Functions to insert Perl documentation and code.  -*- Mode: Emacs-Lisp -*-
;;;; Lukas Mueller, March 6, 2005, modified by Rob Buels
;;;; Rewritten by Marty, Valentine's Day, 2006.  <3

;;; The interactively-callable functions are

;;; * insert-pod-header
;;; * insert-function
;;; * insert-accessors

;; The first several functions return strings, and have no
;; side-effects.  The inserting functions are all named insert-*,
;; below.

(defun pod-header-for-name (name)
  "Return a template POD header for documenting NAME."
  (concat 
    "=head2 " name "

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

"))

(defun sub-skeleton-for-name (name &optional body-string)
  "Return a Perl subroutine skeleton with name NAME and 
optional body BODY-STRING."
  (concat "sub " name " {
" body-string "
}

"))

(defun sub-skeleton-with-pod-for-name (name &optional body-string)
  "Return a Perl subroutine skeleton POD header for with a
subroutine named NAME."
  (concat (pod-header-for-name name)
	  (sub-skeleton-for-name name body-string)))

;; XXX: since we're autogenerating them, the getter and setter 
;; methods might as well be strict about checking the argument
;; list (especially the setter).  Another time, perhaps.
(defun getter-sub-for-attribute (attribute-name)
  "Return a Perl subroutine skeleton defining a Java-style \"get\"
method for an attribute named ATTRIBUTE-NAME (in an instance 
implemented as a hash table)."
  (let ((name (concat "get_" attribute-name)))
    (sub-skeleton-with-pod-for-name 
     name
     ;; The spaces are for indentation.
     (concat "  my $self=shift;
  return $self->{" attribute-name "};
"))))

(defun setter-sub-for-attribute (attribute-name)
  "Return a Perl subroutine skeleton defining a Java-style \"set\"
method for an attribute named ATTRIBUTE-NAME (in an instance 
implemented as a hash table)."
  (let ((name (concat "set_" attribute-name)))
    (sub-skeleton-with-pod-for-name 
     name
     ;; The spaces are for indentation.
     (concat "  my $self=shift;
  $self->{" attribute-name "}=shift;"))))

;; The old version of this function was interactive, but it took a numeric
;; argument, rather than prompting, and so was only actually called 
;; non-interactively by insert-pod-header-interactive.  The call to
;; message is innocuous enough.
(defun insert-pod-header (&optional name)
  "Insert a template POD header for a subroutine named NAME at point."
  (interactive "sEnter function name: ")
  (message "inserting function %s" name) 
  (insert (pod-header-for-name name)))

;; Backward compatibility name.
;; Note for future Lispers: the sharp-quote syntax has been avoided
;; (in favor of FUNCTION) here to keep things simpler for those
;; unfamiliar with Elisp.
(defalias 'insert-pod-header-interactive
    (function insert-pod-header))

(defun insert-function-code (name)
  "Insert a skeleton Perl subroutine named NAME at point."
  (insert (sub-skeleton-for-name name)))

(defun insert-function (name &optional sub-maker-function)
  "Insert a skeleton Perl subroutine named NAME with
corresponding POD header at point.  Optional argument
SUB-MAKER-FUNCTION must be a function that takes NAME and returns
subroutine skeleton text; if unsupplied, SUB-SKELETON-FOR-NAME
will be used."
  (interactive "sEnter function name: ")
  (insert
   (funcall (or sub-maker-function 
		(function sub-skeleton-with-pod-for-name))
	    name)))

;; This has been changed slightly from its old version: the old
;; prompt asked for a function name, though the function generates
;; two accessor subroutines.  <shrug>
(defun insert-accessors (name)
  "Insert Java-style \"get\" and \"set\" methods and corresponding
POD headers for an attribute (a.k.a. instance variable) named NAME
in an instance implemented as a hash table."
  (interactive "sEnter attribute/instance variable name: ")

  (insert 
  (concat 
    "=head2 accessors get_" name ", set_" name "

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_" name " {
  my $self = shift;
  return $self->{" name "}; 
}

sub set_" name " {
  my $self = shift;
  $self->{"name"} = shift;
}
")))

