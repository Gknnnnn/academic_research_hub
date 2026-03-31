# Regression Summary

                            OLS Regression Results                            
==============================================================================
Dep. Variable:                 co2_kt   R-squared:                       0.994
Model:                            OLS   Adj. R-squared:                  0.993
Method:                 Least Squares   F-statistic:                     1652.
Date:                Mon, 30 Mar 2026   Prob (F-statistic):           8.00e-24
Time:                        16:59:27   Log-Likelihood:                -78.641
No. Observations:                  24   AIC:                             163.3
Df Residuals:                      21   BIC:                             166.8
Df Model:                           2                                         
Covariance Type:            nonrobust                                         
===============================================================================
                  coef    std err          t      P>|t|      [0.025      0.975]
-------------------------------------------------------------------------------
Intercept       9.7864      5.992      1.633      0.117      -2.674      22.247
gdp_usd     -4.047e-11   1.14e-11     -3.566      0.002   -6.41e-11   -1.69e-11
elec_kwh_pc     0.1347      0.004     31.487      0.000       0.126       0.144
==============================================================================
Omnibus:                       10.397   Durbin-Watson:                   1.740
Prob(Omnibus):                  0.006   Jarque-Bera (JB):                8.411
Skew:                           1.232   Prob(JB):                       0.0149
Kurtosis:                       4.529   Cond. No.                     3.19e+12
==============================================================================

Notes:
[1] Standard Errors assume that the covariance matrix of the errors is correctly specified.
[2] The condition number is large, 3.19e+12. This might indicate that there are
strong multicollinearity or other numerical problems.