; Copyright (C) 2000, 2001, 2002 RiskMap srl
;
; This file is part of QuantLib, a free-software/open-source library
; for financial quantitative analysts and developers - http://quantlib.org/
;
; QuantLib is free software developed by the QuantLib Group; you can
; redistribute it and/or modify it under the terms of the QuantLib License;
; either version 1.0, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; QuantLib License for more details.
;
; You should have received a copy of the QuantLib License along with this
; program; if not, please email ferdinando@ametrano.net
;
; The QuantLib License is also available at http://quantlib.org/license.html
; The members of the QuantLib Group are listed in the QuantLib License
;
; $Id$

(require-library "quantlib.ss" "quantlib")
(load "common.scm")

(define (Risk-statistics-test)
  (deleting-let ((s (new-RiskStatistics) delete-RiskStatistics))
    (for-each-combination ((average '(-100.0 0.0 100.0))
                           (sigma '(0.1 1.0 10.0)))
      (risk-statistics-test-case s average sigma))))

(define (risk-statistics-test-case stats average sigma)
  (define pi (acos -1.0))
  (define (gaussian x)
    (let ((dx (- x average)))
      (/ (exp (/ (- (* dx dx)) (* 2.0 sigma sigma)))
         (* sigma (sqrt (* 2.0 pi))))))
  (let* ((N 25000)
         (sigmas 15)
         (target average)
         (normal (new-NormalDistribution average sigma))
         (data-min (- average (* sigmas sigma)))
         (data-max (+ average (* sigmas sigma)))
         (h (grid-step data-min data-max N))
         (data (grid data-min data-max N))
         (weights (map gaussian data)))
    (RiskStatistics-add-weighted-sequence stats data weights)
    (check "number of samples"
           (RiskStatistics-samples stats)
           N
           0)
    (check "sum of weights"
           (RiskStatistics-weight-sum stats)
           (apply + weights)
           0.0)
    (check "minimum value"
           (RiskStatistics-min stats)
           (apply min data)
           0.0)
    (check "maximum value"
           (RiskStatistics-max stats)
           (apply max data)
           1.0e-13)
    (check "mean value"
           (RiskStatistics-mean stats)
           average
           (if (= average 0.0)
               1.0e-13
               (* (abs average) 1.0e-13)))
    (check "variance"
           (RiskStatistics-variance stats)
           (* sigma sigma)
           (* sigma sigma 1.0e-4))
    (check "standard deviation"
           (RiskStatistics-standard-deviation stats)
           sigma
           (* sigma 1.0e-4))
    (check "skewness"
           (RiskStatistics-skewness stats)
           0.0
           1.0e-4)
    (check "kurtosis"
           (RiskStatistics-kurtosis stats)
           0.0
           1.0e-1)

    (deleting-let ((cum (new-CumulativeNormalDistribution average sigma)
                        delete-CumulativeNormalDistribution))
      (let ((two-std-dev (CumulativeNormalDistribution-call
                          cum
                          (+ average (* 2 sigma)))))
        (let ((right-potential-upside (max 0.0 (+ average (* 2 sigma)))))
          (check "potential upside"
                 (RiskStatistics-potential-upside stats two-std-dev)
                 right-potential-upside
                 (if (= 0.0 right-potential-upside)
                     1.0e-3
                     (* right-potential-upside 1.0e-3))))
        (let ((right-VAR (- (min 0.0 (- average (* 2 sigma))))))
          (check "value at risk"
                 (RiskStatistics-value-at-risk stats two-std-dev)
                 right-VAR
                 (if (= 0.0 right-VAR)
                     1.0e-3
                     (* 1.0e-3 right-VAR))))
        (let ((right-ex-shortfall
               (- (min 
                   (- average
                      (/ (* sigma sigma (gaussian (- average (* 2 sigma))))
                         (- 1 two-std-dev)))
                   0.0))))
          (check "expected shortfall"
                 (RiskStatistics-expected-shortfall stats two-std-dev)
                 right-ex-shortfall
                 (if (= 0.0 right-ex-shortfall)
                     1.0e-4
                     (* 1.0e-4 right-ex-shortfall))))
        (check "shortfall"
               (RiskStatistics-shortfall stats target)
               0.5
               0.5e-8)
        (let ((right-avg-shortfall (/ sigma (sqrt (* 2 pi)))))
          (check "average shortfall"
                 (RiskStatistics-average-shortfall stats target)
                 right-avg-shortfall
                 (* 1.0e-4 right-avg-shortfall)))
        
        (RiskStatistics-reset! stats)))))
