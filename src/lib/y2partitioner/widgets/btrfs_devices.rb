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
require "yast2/popup"
require "cwm"
require "y2partitioner/widgets/btrfs_metadata_raid_level"
require "y2partitioner/widgets/btrfs_data_raid_level"
require "y2partitioner/widgets/btrfs_devices_selector"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove physical volumes to a LVM volume group
    # Widget to select the md parity
    class BtrfsDevices < CWM::CustomWidget
      # @param controller [Actions::Controllers::Md]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

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

      def help
        help_for_raid_levels + help_for_default_raid_level
      end

      # Validates the selected physical volumes
      # @macro seeAbstractWidget
      #
      # @see #selected_devices_validation
      # @see #size_validation
      #
      # @note An error popup is shown when there is some error in selected devices.
      #
      # @return [Boolean]
      def validate
        current_errors = errors
        return true if current_errors.none?

        message = current_errors.join("\n\n")
        Yast2::Popup.show(message, headline: :error, buttons: :ok)

        false
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

      def help_for_raid_levels
        _("<h4><b>Btrfs RAID levels</b></h4>" \
          "<p> Btrfs supports the following RAID levels for both, metadata and data:" \
            "<ul>" \
              "<li>" \
                "<b>DUP:</b> stores two copies of each piece of data on the same device. " \
                "This is similar to RAID1, and protects against block-level errors on the device, " \
                "but does not provide any guarantees if the device fails. Only one device must be " \
                "be selected to use DUP." \
              "</li>" \
              "<li>" \
                "<b>SINGLE:</b> stores a single copy of each piece of data. Btrfs requires a minimum " \
                "of one device to use SINGLE." \
              "</li>" \
              "<li>" \
                "<b>RAID0:</b> provides no form of error recovery, but stripes a " \
                "single copy of data across multiple devices for performance purpose. Btrfs requires " \
                "a minimum of two devices to use RAID0." \
              "</li>" \
              "<li>" \
                "<b>RAID1:</b> stores two complete copies of each piece of data. " \
                "Each copy is stored on a different device. Btrfs requires a minimum of two devices " \
                "to use RAID1." \
              "</li>" \
              "<li>" \
                "<b>RAID10:</b> stores two complete copies of each piece of data, and also stripes " \
                "each copy across multiple devices for performance. Btrfs requires a minimum of five " \
                "devices to use RAID10" \
              "</li>" \
            "</ul>" \
          "</p>")
      end

      def help_for_default_raid_level
        _("<p>" \
            "When <b>DEFAULT</b> RAID level is used, Btrfs will select a RAID level depending on " \
            "whether the filesystem is being created on top of multiple devices or using only one " \
            "device. For a single-device Btrfs, the tool also will distinguish between rotational " \
            "or not-rotational devices to choose the default value." \
          "</p>")
      end

      def errors
        [
          metadata_devices_error,
          data_devices_error
        ].compact
      end

      # Validates that at least one physical volume was added to the volume group
      #
      # @note An error popup is shown when no physical volume was added.
      #
      # @return [Boolean]
      def selected_devices_error
        return nil if controller.selected_devices.any?

        # TRANSLATORS: Error message when no device is selected
        _("Select at least one device.")
      end

      def metadata_devices_error
        raid_level_devices_error(:metadata)
      end

      def data_devices_error
        raid_level_devices_error(:data)
      end

      def raid_level_devices_error(data)
        return nil unless filesystem

        allowed_raid_levels = allowed_raid_levels(data)
        selected_raid_level = selected_raid_level(data)

        return nil if allowed_raid_levels.include?(selected_raid_level)

        format(
          _("According to the selected devices, only the following %{data}\n" \
            "RAID levels can be used: %{levels}."),
          data:   data.to_s,
          levels: allowed_raid_levels.map(&:to_human_string).join(", ")
        )
      end

      def allowed_raid_levels(data)
        controller.allowed_raid_levels(data)
      end

      def selected_raid_level(data)
        controller.send("#{data}_raid_level")
      end

      def filesystem
        controller.filesystem
      end
    end
  end
end
