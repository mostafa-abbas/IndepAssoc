# IndepAssoc 0.5.0

Initial public release. Implements five confounding-adjustment methods
(regression, matching, stratification, IPTW, AIPW) for testing whether
an exposure is independently associated with an outcome after adjusting
for measured confounders, generalizing the shared analysis pipeline from
two peer-reviewed cardiac-surgery studies (see README).

Validated against the RHC benchmark cohort (Connors et al. 1996) and
NHEFS/lalonde (Hernán & Robins; Dehejia & Wahba). See vignettes for
worked examples.