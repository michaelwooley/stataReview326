# stataReview326

This is a simple review of the scripting language Stata created for a class that I TAed. It also doubles as an example of how 
to:
1. Use Stata with Knitr. (Yes, that's right, we're calling Stata from R. Why not just teach students R, you ask? As I said, I was the TA.)
2. Make output toggle-able (Lines 1-23).
3. Add custom code highlighting (Line 25).

## Viewing the Final Result
The file `main.html` shows the results. You can also view the results at [RPubs](http://rpubs.com/wmwooley/stata_review_326).

## Compiling the File
The R-markdown file `main.rmd` ought to be compileable with RStudio once one changes:
- (Line 55) `statapath` is the path to your Stata executable. _Note that this will only work if you already have Stata installed!_
- (Line 56) `rootpath` is the directory that contains the `main.rmd` file. 
