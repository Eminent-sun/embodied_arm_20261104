#!/usr/bin/env python3
import argparse,json,sys,time,unittest
from pathlib import Path
BASE=Path(__file__).resolve().parents[2];APP=BASE/'host/app';sys.path[:0]=[str(APP/x) for x in ['vision','communication','planning','tests']]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=BASE/'metrics/logs');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
class Result(unittest.TextTestResult):
 def startTest(self,test):self.t=time.perf_counter();super().startTest(test)
 def stopTest(self,test):
  failed=any(t==test for t,_ in self.failures+self.errors);skipped=any(t==test for t,_ in self.skipped)
  rows.append({'test':test.id(),'duration_s':time.perf_counter()-self.t,'outcome':'failed' if failed else 'skipped' if skipped else 'passed'});super().stopTest(test)
rows=[];suite=unittest.defaultTestLoader.discover(str(APP/'tests'));start=time.perf_counter()
with (a.output/'unit_tests.log').open('w') as log:result=unittest.TextTestRunner(stream=log,verbosity=2,resultclass=Result).run(suite)
report={'tests_run':result.testsRun,'passed':sum(r['outcome']=='passed' for r in rows),'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),'duration_s':time.perf_counter()-start,'test_cases':rows,'scope':'Offline software tests and synthetic geometry/network fixtures, no hardware motion'}
(a.output/'unit_tests.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='test_cases'},indent=2));sys.exit(not result.wasSuccessful())
