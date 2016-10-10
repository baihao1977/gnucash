(use-modules (gnucash gnc-module))

(gnc:module-begin-syntax (gnc:module-load "gnucash/app-utils" 0))

(use-modules (gnucash engine test test-extras))
(use-modules (gnucash report standard-reports cash-flow))
(use-modules (gnucash report report-system))

(define (run-test)
  (and (test test-one-tx-in-cash-flow)
       (test test-one-tx-skip-cash-flow)
       (test test-both-way-cash-flow)))

(define structure
  (list "Root" (list (cons 'type ACCT-TYPE-ASSET))
	(list "Asset" 
	      (list "Bank")
	      (list "Wallet"))
	(list "Expenses" (list (cons 'type ACCT-TYPE-EXPENSE)))))

(define (NDayDelta tp n)
  (let* ((day-secs (* 60 60 24 n)) ; n days in seconds is n times 60 sec/min * 60 min/h * 24 h/day
         (new-secs (- (car tp) day-secs))
         (new-tp (cons new-secs 0)))
    new-tp))

(define (test-one-tx-in-cash-flow)
  (let* ((env (create-test-env))
	 (account-alist (env-create-account-structure-alist env structure))
	 (bank-account (cdr (assoc "Bank" account-alist)))
	 (wallet-account (cdr (assoc "Wallet" account-alist)))
	 (expense-account (cdr (assoc "Expenses" account-alist)))
	 (today (localtime (current-time)))
         (to-date-tp (gnc-dmy2timespec-end (tm:mday today) (+ 1 (tm:mon today)) (+ 1900 (tm:year today))))
         (from-date-tp (NDayDelta to-date-tp 1))
	 (exchange-fn (lambda (currency amount date) amount))
	 (report-currency (gnc-default-report-currency))
	 )
    (env-create-transaction env to-date-tp bank-account expense-account (gnc:make-gnc-numeric 100 1))
    (let ((result (cash-flow-calc-money-in-out (list (cons 'accounts (list bank-account))
						     (cons 'to-date-tp to-date-tp)
						     (cons 'from-date-tp from-date-tp)
						     (cons 'report-currency report-currency)
						     (cons 'include-trading-accounts #f)
						     (cons 'to-report-currency exchange-fn)))))
      (let* ((money-in-collector (cdr (assq 'money-in-collector result)))
	     (money-out-collector (cdr (assq 'money-out-collector result)))
	     (money-in-alist (cdr (assq 'money-in-alist result)))
	     (money-out-alist (cdr (assq 'money-out-alist result)))
	     (expense-acc-in-collector (cadr (assoc expense-account money-in-alist))))
	(and (null? money-out-alist)
	     (equal? (gnc:make-gnc-numeric 10000 100)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity expense-acc-in-collector
									   report-currency exchange-fn)))
	     (equal? (gnc:make-gnc-numeric 10000 100)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-in-collector
									   report-currency exchange-fn)))
	     (equal? (gnc:make-gnc-numeric 0 1)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-out-collector
									   report-currency exchange-fn)))
	     )))))

(define (test-one-tx-skip-cash-flow)
  (let* ((env (create-test-env))
	 (account-alist (env-create-account-structure-alist env structure))
	 (bank-account (cdr (assoc "Bank" account-alist)))
	 (wallet-account (cdr (assoc "Wallet" account-alist)))
	 (expense-account (cdr (assoc "Expenses" account-alist)))
	 (today (localtime (current-time)))
         (to-date-tp (gnc-dmy2timespec-end (tm:mday today) (+ 1 (tm:mon today)) (+ 1900 (tm:year today))))
         (from-date-tp (NDayDelta to-date-tp 1))
	 (exchange-fn (lambda (currency amount date) amount))
	 (report-currency (gnc-default-report-currency))
	 )
    (env-create-transaction env to-date-tp bank-account wallet-account (gnc:make-gnc-numeric 100 1))
    (let ((result (cash-flow-calc-money-in-out (list (cons 'accounts (list wallet-account bank-account))
						     (cons 'to-date-tp to-date-tp)
						     (cons 'from-date-tp from-date-tp)
						     (cons 'report-currency report-currency)
						     (cons 'include-trading-accounts #f)
						     (cons 'to-report-currency exchange-fn)))))
      (let* ((money-in-collector (cdr (assq 'money-in-collector result)))
	     (money-out-collector (cdr (assq 'money-out-collector result)))
	     (money-in-alist (cdr (assq 'money-in-alist result)))
	     (money-out-alist (cdr (assq 'money-out-alist result))))
	(and (null? money-in-alist)
	     (null? money-out-alist)
	     (equal? (gnc:make-gnc-numeric 0 1)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-in-collector
									   report-currency exchange-fn)))
	     (equal? (gnc:make-gnc-numeric 0 1)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-out-collector
									   report-currency exchange-fn))))))))

(define (test-both-way-cash-flow)
  (let* ((env (create-test-env))
	 (account-alist (env-create-account-structure-alist env structure))
	 (bank-account (cdr (assoc "Bank" account-alist)))
	 (wallet-account (cdr (assoc "Wallet" account-alist)))
	 (expense-account (cdr (assoc "Expenses" account-alist)))
	 (today (localtime (current-time)))
         (to-date-tp (gnc-dmy2timespec-end (tm:mday today) (+ 1 (tm:mon today)) (+ 1900 (tm:year today))))
         (from-date-tp (NDayDelta to-date-tp 1))
	 (exchange-fn (lambda (currency amount date) amount))
	 (report-currency (gnc-default-report-currency))
	 )
    (env-create-transaction env to-date-tp bank-account expense-account (gnc:make-gnc-numeric 100 1))
    (env-create-transaction env to-date-tp expense-account bank-account (gnc:make-gnc-numeric 50 1))
    (let ((result (cash-flow-calc-money-in-out (list (cons 'accounts (list wallet-account bank-account))
						     (cons 'to-date-tp to-date-tp)
						     (cons 'from-date-tp from-date-tp)
						     (cons 'report-currency report-currency)
						     (cons 'include-trading-accounts #f)
						     (cons 'to-report-currency exchange-fn)))))
      (let* ((money-in-collector (cdr (assq 'money-in-collector result)))
	     (money-out-collector (cdr (assq 'money-out-collector result)))
	     (money-in-alist (cdr (assq 'money-in-alist result)))
	     (money-out-alist (cdr (assq 'money-out-alist result)))
	     (expense-acc-in-collector (cadr (assoc expense-account money-in-alist)))
	     (expense-acc-out-collector (cadr (assoc expense-account money-out-alist)))
	     (expenses-in-total (gnc:gnc-monetary-amount (gnc:sum-collector-commodity expense-acc-in-collector
										      report-currency
										      exchange-fn)))
	     (expenses-out-total (gnc:gnc-monetary-amount (gnc:sum-collector-commodity expense-acc-out-collector
										       report-currency
										       exchange-fn))))
	(and (equal? (gnc:make-gnc-numeric 10000 100) expenses-in-total)
	     (equal? (gnc:make-gnc-numeric 5000 100) expenses-out-total)
	     (equal? (gnc:make-gnc-numeric 10000 100)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-in-collector
									   report-currency exchange-fn)))
	     (equal? (gnc:make-gnc-numeric 5000 100)
		     (gnc:gnc-monetary-amount (gnc:sum-collector-commodity money-out-collector
									   report-currency exchange-fn))))))))
