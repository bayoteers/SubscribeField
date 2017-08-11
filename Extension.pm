# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012-2017 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jolla.com>

package Bugzilla::Extension::SubscribeField;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Extension::SubscribeField::Util;

use Bugzilla::Config qw(write_params);
use Bugzilla::Constants;

use List::MoreUtils qw(any);

our $VERSION = '0.01';

# "unique" id for email recipient relationship type
use constant REL_SUBSCRIBER => 37;

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{SubscribeField} = "Bugzilla::Extension::SubscribeField::Params";
}

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    my $schema = $args->{schema};

    # User field subscriptions table
    $schema->{field_subscriptions} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            user_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'profiles',
                    COLUMN => 'userid',
                    DELETE => 'CASCADE',
                },
            },
            field => {
                TYPE => 'varchar(64)',
                NOTNULL => 1,
            },
            value => {
                TYPE => 'varchar(64)',
                NOTNULL => 1,
            },
        ],
        INDEXES => [
            field_subscriptions_uniq_idx => {
                FIELDS => ['user_id', 'field', 'value'],
                TYPE => 'UNIQUE',
            },
        ],
    };
}

sub user_preferences {
    my ($self, $args) = @_;
    my ($current_tab, $save_changes, $handled, $vars) = @$args{
        qw(current_tab save_changes handled vars)};
    return unless $current_tab eq 'subscriptions';
    my $user = Bugzilla->user;

    my @fields = @{Bugzilla->params->{subscription_fields}};
    if ($save_changes) {
        my $subscriptions = {};
        for my $field (@fields) {
            my $values = Bugzilla->input_params->{$field};
            next unless defined $values;
            $values = [$values] unless (ref $values eq 'ARRAY');
            for my $value (@$values) {
                $subscriptions->{$field}->{$value} = 1;
            }
        }
        update_subscribtions($user, $subscriptions);
    }
    my %values;
    for my $fname (@fields) {
        if ($fname eq 'keywords') {
            # Keywords doesn't work like regular multiselect fileds
            $values{$fname} = [
                map {$_->name} Bugzilla::Keyword->get_all()
            ];

        } else {
            $values{$fname} = [
                map {$_->name} @{Bugzilla::Field->check($fname)->legal_values}
            ];
        }
    }
    $vars->{subscribed} = get_subscribtions($user);
    $vars->{values} = \%values;

    $$handled = 1;
}

sub template_before_process {
    my ($self, $args) = @_;
    if ($args->{file} eq 'account/prefs/email.html.tmpl' ||
        $args->{file} eq 'global/reason-descs.none.tmpl') {
        $args->{vars}->{rel_id_subscriber} = REL_SUBSCRIBER;
    }
}

sub bugmail_relationships {
    my ($self, $args) = @_;
    $args->{relationships}->{+REL_SUBSCRIBER} = 'subscriber';
}

sub bugmail_recipients {
    my ($self, $args) = @_;
    my @subfields = @{Bugzilla->params->{subscription_fields}};
    return unless scalar @subfields;
    my ($bug, $recipients, $users, $diffs) = @$args{
        qw(bug recipients users diffs)};
    my $fields = Bugzilla->fields({by_name => 1});
    for my $fname (@subfields) {
        my @values;
        if ($fields->{$fname}->type == FIELD_TYPE_SINGLE_SELECT) {
            push(@values, $bug->$fname);
        } elsif ($fields->{$fname}->type == FIELD_TYPE_MULTI_SELECT) {
            push(@values, @{$bug->$fname});
        } elsif ($fields->{$fname}->type == FIELD_TYPE_KEYWORDS) {
            push(@values, split(/, /, $bug->$fname));
        }
        # TODO We might want to also notify when the value has been removed
        #   Now the mails are only send to subcribers based on the bug field
        #   values after the change that is triggering the mail
        my $subscribers = get_field_subscribers($fname, \@values);
        for my $uid (@$subscribers) {
            $recipients->{$uid}->{+REL_SUBSCRIBER} = 1;
        }
    }
}

sub object_before_delete {
    my ($self, $args) = @_;
    my $obj = $args->{object};
    if ($obj->isa('Bugzilla::Field::ChoiceInterface') ||
            $obj->isa('Bugzilla::Keyword')) {
        # Remove subscriptions when field value is removed
        my $field = $obj->isa('Bugzilla::Keyword') ? 'keywords' :
                                                     $obj->field->name;
        return unless (any {$field eq $_}
                @{Bugzilla->params->{subscription_fields}});
        my $value = $obj->name;
        Bugzilla->dbh->do(
            'DELETE FROM field_subscriptions WHERE field = ? AND value = ?',
            undef, $field, $value);
    } elsif ($obj->isa('Bugzilla::Field')) {
        # Remove subscriptions when field is removed
        my $field = $obj->name;
        Bugzilla->dbh->do(
            'DELETE FROM field_subscriptions WHERE field = ?',
            undef, $field);
    }
}

sub object_end_of_update {
    my ($self, $args) = @_;
    my ($obj, $changes) = @$args{qw(object changes)};
    if ($obj->isa('Bugzilla::Field::ChoiceInterface') ||
            $obj->isa('Bugzilla::Keyword')) {
        # Update subscriptions when field value is changed
        my $field = $obj->isa('Bugzilla::Keyword') ? 'keywords' :
                                                     $obj->field->name;
        return unless (
            any {$field eq $_} @{Bugzilla->params->{subscription_fields}});
        my $change = (
            any {$field eq $_} qw(keywords classification product component)) ?
                $changes->{name} :
                $changes->{value};
        return unless (defined $change);
        Bugzilla->dbh->do(
            'UPDATE field_subscriptions '.
            'SET value = ? '.
            'WHERE field = ? AND value = ?',
            undef, ($change->[1], $field, $change->[0]));
    } elsif ($obj->isa('Bugzilla::Field') && $obj->obsolete &&
            defined $changes->{obsolete})
    {
        # Update subscript_fields param when field is set as obsolete.
        my $field = $obj->name;
        my @old_fields = @{Bugzilla->params->{subscription_fields}};
        my @new_fields = grep {$field ne $_} @old_fields;
        if (scalar @old_fields != scalar @new_fields) {
            Bugzilla->params->{subscription_fields} = \@new_fields;
            write_params();
        }
    }
}

# Helper for sanity check and repair for getting invalid subscriptions
sub _get_bad_subscriptions {
    my @fields = @{Bugzilla->params->{subscription_fields}};
    my $dbh = Bugzilla->dbh;
    if (@fields) {
        my $query = "SELECT * FROM field_subscriptions WHERE ".
            "field NOT IN ('".join("','", @fields)."') ";
        foreach my $field (@fields) {
            my @values = $field eq "keywords" ?
                Bugzilla::Keyword->get_all() :
                @{Bugzilla->fields({by_name=>1})->{$field}->legal_values};
            $query .= "OR (field = '$field' AND value NOT IN ('"
                .join("','", map {$_->name} @values)."'))\n";
        }

        return $dbh->selectall_hashref($query, "id");
    } else {
        return $dbh->selectall_hashref(
            "SELECT * FROM field_subscriptions", "id");
    }
}

sub sanitycheck_check {
    my ($self, $args) = @_;
    my $status = $args->{'status'};
    $status->('subscribefield_check');

    my $bad_subs = _get_bad_subscriptions();
    if (%$bad_subs) {
        $status->('subscribefield_check_alert',
            {subs => $bad_subs}, 'alert');
        $status->('subscribefield_check_prompt');
    }
}

sub sanitycheck_repair {
    my ($self, $args) = @_;

    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $status = $args->{'status'};
    if ($cgi->param('subscribefield_repair')) {
        $status->('subscribefield_repair_start');
        my $bad_subs = _get_bad_subscriptions();
        my @ids = keys %$bad_subs;
        $dbh->do("DELETE FROM field_subscriptions WHERE ".
            $dbh->sql_in('id', \@ids));
        $status->('subscribefield_repair_end');
    }
}

__PACKAGE__->NAME;
