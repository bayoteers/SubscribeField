# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

package Bugzilla::Extension::SubscribeField::Params;
use strict;
use warnings;

use Bugzilla::Config::Common;
use Bugzilla::Constants;

sub get_param_list {
    my $ftypes = [FIELD_TYPE_SINGLE_SELECT, FIELD_TYPE_MULTI_SELECT, FIELD_TYPE_KEYWORDS];
    my @fields = sort(map {$_->name} @{Bugzilla->fields({type => $ftypes})});
    return (
        {
            name => 'subscription_fields',
            type => 'm',
            choices => \@fields,
            default => [],
        },
    );
}

1;