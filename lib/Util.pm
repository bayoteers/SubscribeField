# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

package Bugzilla::Extension::SubscribeField::Util;
use strict;
use base qw(Exporter);
our @EXPORT = qw(
    get_subscribtions
    update_subscribtions
    get_field_subscribers
);

use Bugzilla::Extension::SubscribeField::Subscription;

sub get_subscribtions {
    my ($user, $field) = @_;
    my $match = {user_id => $user->id};
    $match->{field} = $field if defined $field;
    my $subs = {};

    for my $sub (@{
        Bugzilla::Extension::SubscribeField::Subscription->match($match)}) {
        $subs->{$sub->field} = {} unless defined $subs->{$sub->field};
        $subs->{$sub->field}->{$sub->value} = 1;
    }
    return $subs;
}

sub update_subscribtions {
    my ($user, $subscriptions) = @_;
    my $subs = Bugzilla::Extension::SubscribeField::Subscription->match({
            user_id => $user->id,
        });
    my @remove;
    for my $sub (@{$subs}) {
        if (defined $subscriptions->{$sub->field}->{$sub->value}) {
            delete $subscriptions->{$sub->field}->{$sub->value};
        } else {
            push(@remove, $sub);
        }
    }
    for my $sub (@remove) {
        $sub->remove_from_db;
    }
    for my $field (keys(%$subscriptions)) {
        for my $value (keys(%{$subscriptions->{$field}})) {
            Bugzilla::Extension::SubscribeField::Subscription->create({
                    user_id => $user->id,
                    field => $field,
                    value => $value,
                });
        }
    }
}

sub get_field_subscribers {
    my ($field, $values) = @_;
    my $values_where = "value IN(".join(',',map('?', @$values)).")";
    my $subs = Bugzilla::Extension::SubscribeField::Subscription->match({
            field => $field,
            value =>$values,
        });
    return [map {$_->user_id} @$subs];
}

1;
