SObject bt = Schema.getGlobalDescribe().get('BenefitType').newSObject();
bt.put('Name', 'Diag BenefitType Test');
try { bt.put('ProcessType', 'ProgramManagement'); } catch (Exception ignored) {}
Database.SaveResult btRes = Database.insert(bt, false);
System.debug('BT insert: ' + btRes.isSuccess() + ' errors: ' + btRes.getErrors());
Id btId = btRes.isSuccess() ? btRes.getId() : null;
SObject prog = Schema.getGlobalDescribe().get('Program').newSObject();
prog.put('Name', 'Diag Test Prog');
insert prog;
SObject ben = Schema.getGlobalDescribe().get('Benefit').newSObject();
ben.put('ProgramId', prog.get('Id'));
ben.put('Name', 'Diag Active Benefit');
ben.put('IsActive', true);
if (btId != null) ben.put('BenefitTypeId', btId);
Database.SaveResult benRes = Database.insert(ben, false);
System.debug('Benefit insert: ' + benRes.isSuccess() + ' errors: ' + benRes.getErrors());
if (benRes.isSuccess()) {
  SObject bQuery = Database.query('SELECT Id, IsActive, BenefitTypeId FROM Benefit WHERE Id = :benRes.getId() LIMIT 1');
  System.debug('IsActive after insert: ' + bQuery.get('IsActive'));
}
