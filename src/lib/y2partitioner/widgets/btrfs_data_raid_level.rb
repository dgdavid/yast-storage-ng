# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2storage/btrfs_raid_level"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove physical volumes to a LVM volume group
    # Widget to select the md parity
    class BtrfsDataRaidLevel < CWM::ComboBox
      # @param controller [Actions::Controllers::Md]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def label
        _("Data RAID Level")
      end

      def help
        _("<p><b>Parity Algorithm:</b> " \
          "The parity algorithm to use with RAID 5/6. " \
          "Left-symmetric is the one that offers maximum performance " \
          "on typical disks with rotating platters." \
          "</p>")
      end

      # @macro seeAbstractWidget
      def opt
        %i(hstretch notify)
      end

      def items
        @controller.raid_levels.map { |p| [p.to_s, p.to_human_string] }
      end

      # @macro seeAbstractWidget
      def init
        self.value = @controller.data_raid_level.to_s
      end

      # @macro seeAbstractWidget
      def store
        @controller.data_raid_level = Y2Storage::BtrfsRaidLevel.find(value)
      end
    end
  end
end
