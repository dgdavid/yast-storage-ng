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

require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/btrfs_metadata_raid_level"
require "y2partitioner/widgets/btrfs_data_raid_level"
require "y2partitioner/widgets/btrfs_devices_selector"

module Y2Partitioner
  module Dialogs
    # Dialog to set Btrfs options like mount point, subvolumes, snapshots, etc.
    class BtrfsDevices < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        super()

        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        VBox(
          Left(
            HVSquash(
              HBox(
                metadata_raid_level_widget,
                HSpacing(1),
                data_raid_level_widget
              )
            )
          ),
          VSpacing(1),
          btrfs_devices_widget
        )
      end

    private

      # @return [Actions::Controllers::Filesystem]
      attr_reader :controller

      def metadata_raid_level_widget
        @metadata_raid_level_widget ||= Widgets::BtrfsMetadataRaidLevel.new(controller)
      end

      def data_raid_level_widget
        @data_raid_level_widget ||= Widgets::BtrfsDataRaidLevel.new(controller)
      end

      # Widget for Btrfs options
      #
      # @return [Widgets::BtrfsOptions]
      def btrfs_devices_widget
        @btrfs_devices_widget ||= Widgets::BtrfsDevicesSelector.new(controller)
      end
    end
  end
end
