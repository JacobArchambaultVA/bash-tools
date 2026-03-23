#!/bin/bash
# bash script for finding uncategorized tests and providing them with the unittest category

find PayerEDI.TAS.CXM/PayerEDI.TAS.CXM.QA.837SpecFlow -type f -name "*.cs" -exec perl -i -pe 's/\[TestMethod\]/[TestMethod, TestCategory("UnitTest")]/g' {} +

