trigger OrderTrigger on Order (after delete,after insert,after undelete,after update,before delete,before insert,before update) {
	new OrderTriggerHandler().execute();
}