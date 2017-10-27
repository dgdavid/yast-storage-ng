# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "cwm"
require "y2partitioner/sequences/edit_blk_device"
require "y2partitioner/widgets/blk_device_button"
require "y2partitioner/ui_state"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the editing workflow (basically mount and format
    # options) on a block device.
    class EditBlkDeviceButton < BlkDeviceButton
      # TRANSLATORS: button label to edit a block device
      def label
        _("Edit...")
      end

      # @see BlkDeviceButton#actions
      def actions
        UIState.instance.select_row(device.sid)
        Sequences::EditBlkDevice.new(device).run
        :redraw
      end
    end
  end
end
