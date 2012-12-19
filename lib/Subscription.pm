# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

use strict;
package Bugzilla::Extension::SubscribeField::Subscription;

use base qw(Bugzilla::Object);

use Bugzilla::Error;
use Bugzilla::Util qw(trim);
use Bugzilla::Field;

use Scalar::Util qw(blessed);

use constant DB_TABLE => 'field_subscriptions';

use constant DB_COLUMNS => (
    'id',
    'CONCAT(field, \':\', value) AS name',
    'user_id',
    'field',
    'value',
);

use constant UPDATE_COLUMNS => qw(
    field
    value
);

use constant VALIDATORS => {
    field => \&_check_field_name,
    value => \&_check_field_value,
};

use constant VALIDATOR_DEPENDENCIES => {
    value => ['field'],
};

# Accessors
###########

sub user_id      { return $_[0]->{user_id}; }
sub field        { return $_[0]->{field}; }
sub value        { return $_[0]->{value}; }

# Mutators
##########

sub set_field   { $_[0]->set('field', $_[1]); }
sub set_value   { $_[0]->set('value', $_[1]); }

# Validators
############

sub _check_field_name {
    my ($invocant, $field) = @_;
    $field = trim($field);
    get_field_id($field);
    return $field;
}

sub _check_field_value {
    my ($invocant, $value, undef, $params) = @_;
    $value = trim($value);
    my $field = blessed($invocant) ? $invocant->field
                                   : $params->{field};
    if ($field eq 'keywords') {
        Bugzilla::Keyword->check($value);
    } else {
        check_field($field, $value);
    }
    return $value;
}

1;
__END__

