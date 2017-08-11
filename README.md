SubscribeField Bugzilla Extension
=================================

This extension allows user to subscribe for bug mail based on selected field
values. Administrator can select any of the select or multiselect bug fileds
for allowed subscription fields.

NOTE: For product field the product group access controls are not taken into
account. So if you have Products that should not be visible to everyone, do not 
enable product filed for subscriptions. And this ofcourse affects also
component field as those are tied to product.


Installation
============

1.  Put extension files in

        extensions/SubscribeField

2.  Run checksetup.pl

3.  Restart your webserver if needed (for exmple when running under mod_perl)

4.  Configure the fields allowed for subscription in 
    Administration > Parameters > SubscribeField
    
