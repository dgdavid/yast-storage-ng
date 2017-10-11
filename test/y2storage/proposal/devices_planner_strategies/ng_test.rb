#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require_relative "../../spec_helper"
require_relative "#{TEST_PATH}/support/devices_planner_context"

require "storage"
require "y2storage"

describe Y2Storage::Proposal::DevicesPlannerStrategies::Ng do
  describe "#planned_devices" do
    using Y2Storage::Refinements::SizeCasts

    include_context "devices planner"

    subject { described_class.new(settings, devicegraph) }

    let(:control_file_content) do
      {
        "proposal" => {
          "lvm" => lvm
        },
        "volumes"  => volumes
      }
    end

    let(:lvm) { false }

    let(:volume) do
      {
        "proposed"      => proposed,
        "mount_point"   => mount_point,
        "fs_type"       => fs_type,
        "desired_size"  => desired_size.to_s,
        "min_size"      => min_size.to_s,
        "max_size"      => max_size.to_s,
        "weight"        => weight,
        "max_size_lvm"  => max_size_lvm.to_s,
        "adjust_by_ram" => adjust_by_ram
      }
    end

    let(:volumes) { [volume] }

    let(:proposed) { true }

    let(:mount_point) { "/" }

    let(:fs_type) { :ext3 }

    let(:desired_size) { 10.GiB }

    let(:min_size) { 5.GiB }

    let(:max_size) { 20.GiB }

    let(:weight) { 100 }

    let(:max_size_lvm) { nil }

    let(:adjust_by_ram) { nil }

    let(:target) { :desired }

    let(:boot_checker) { instance_double("Y2Storage::BootRequirementChecker") }

    let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

    let(:devicegraph) { instance_double("Y2Storage::Devicegraph") }

    subject { described_class.new(settings, devicegraph) }

    it "returns an array of planned devices" do
      expect(subject.planned_devices(:desired)).to be_a Array
      expect(subject.planned_devices(:desired)).to all(be_a(Y2Storage::Planned::Device))
    end

    it "includes the partitions needed by BootRequirementChecker" do
      expect(subject.planned_devices(:desired)).to include(
        an_object_having_attributes(mount_point: "/one_boot", filesystem_type: xfs),
        an_object_having_attributes(mount_point: "/other_boot", filesystem_type: vfat)
      )
    end

    context "when a volume is specified in <volumes> section" do
      before do
        settings.encryption_password = password
      end

      let(:password) { nil }

      let(:planned_devices) { subject.planned_devices(target) }

      let(:planned_device) { planned_devices.detect { |d| d.mount_point == mount_point } }

      context "and the volume is not proposed to be created" do
        let(:proposed) { false }

        it "does not plan a device for the <volume> entry" do
          expect(planned_devices).to_not include(an_object_having_attributes(mount_point: mount_point))
        end
      end

      context "and the volume is proposed to be created" do
        let(:proposed) { true }

        it "plans a device for the <volume> entry" do
          expect(planned_devices).to include(an_object_having_attributes(mount_point: mount_point))
        end

        context "and it is proposing a partition-based setup" do
          let(:lvm) { false }

          context "with encryption" do
            let(:password) { "12345678" }

            it "plans an encrypted partition" do
              expect(planned_device).to be_a(Y2Storage::Planned::Partition)
              expect(planned_device.encrypt?).to eq(true)
            end
          end

          context "without encryption" do
            let(:password) { nil }

            it "plans an plain partition" do
              expect(planned_device).to be_a(Y2Storage::Planned::Partition)
              expect(planned_device.encrypt?).to eq(false)
            end
          end
        end

        context "and it is proposing a LVM-based setup" do
          let(:lvm) { true }

          context "with encryption" do
            let(:password) { "12345678" }

            it "plans a plain logical volume" do
              expect(planned_device).to be_a(Y2Storage::Planned::LvmLv)
              expect(planned_device.encrypt?).to eq(false)
            end
          end

          context "without encryption" do
            let(:password) { nil }

            it "plans a plain logical volume" do
              expect(planned_device).to be_a(Y2Storage::Planned::LvmLv)
              expect(planned_device.encrypt?).to eq(false)
            end
          end
        end

        context "when it is adjusting the weight" do
          it "sets weight value according to <volume> entry" do
            expect(planned_device.weight).to eq(weight)
          end

          context "and there is other volume with weight fallback" do
            let(:home) do
              {
                "proposed"      => home_proposed,
                "mount_point"   => "/home",
                "fs_type"       => "xfs",
                "weight"        => home_weight,
                "desired_size"  => home_desired_size.to_s,
                "min_size"      => home_min_size.to_s,
                "max_size"      => home_max_size.to_s,
                "max_size_lvm"  => home_max_size_lvm.to_s,
                "fallback_for_weight" => fallback_for_weight
              }
            end

            let(:home_proposed) { false }

            let(:home_weight) { 50 }

            let(:home_desired_size) { 10.GiB }

            let(:home_min_size) { 8.GiB }

            let(:home_max_size) { 15.GiB }

            let(:home_max_size_lvm) { 5.GiB }

            let(:fallback_for_weight) { nil }

            let(:volumes) { [volume, home] }

            context "and that volume is proposed" do
              let(:home_proposed) { true }

              it "sets weight whithout include fallback values" do
                expect(planned_device.weight).to eq(weight)
              end
            end

            context "and that volume is not proposed" do
              let(:home_proposed) { false }

              context "and the fallback for weight is not the current volume" do
                let(:fallback_for_weight) { "swap" }

                it "sets weight whithout include fallback values" do
                  expect(planned_device.weight).to eq(weight)
                end
              end

              context "and the fallback for weight is the current volume" do
                let(:fallback_for_weight) { mount_point }

                it "sets weight taking into account the fallback values" do
                  expect(planned_device.weight).to eq(weight + home_weight)
                end
              end
            end
          end
        end

        context "when it is adjusting the max_size" do
          context "and it is proposing a partition-based setup" do
            let(:lvm) { false }

            it "sets max_size value according to <volume> entry" do
              expect(planned_device.max_size).to eq(max_size)
            end
          end

          context "and it is proposing a LVM-based setup" do
            let(:lvm) { true }

            context "and max_size_lvm is specified" do
              let(:max_size_lvm) { 30.GiB }

              it "sets max_size value according to max_size_lvm in <volume> entry" do
                expect(planned_device.max_size).to eq(max_size_lvm)
              end
            end

            context "and max_size_lvm is not specified" do
              let(:max_size_lvm) { nil }

              it "sets max_size value according to max_size in <volume> entry" do
                expect(planned_device.max_size).to eq(max_size)
              end
            end
          end
        end

        context "when it is adjunsting the min_size" do
          context "and it is calculating desired sizes" do
            let(:target) { :desired }

            it "sets min_size value according to the desired_size in <volume> entry" do
              expect(planned_device.min_size).to eq(desired_size)
            end
          end

          context "and it is calculating min sizes" do
            let(:target) { :min }

            it "sets min_size value according to the min_size in <volume> entry" do
              expect(planned_device.min_size).to eq(min_size)
            end
          end
        end

        context "when it is using adjust_by_ram" do
          let(:adjust_by_ram) { true }

          let(:desired_size) { 1.GiB }

          let(:max_size) { 2.GiB }

          it "extends min_size and max_size to ram size if necessary" do
            expect(planned_device.min_size).to eq(8.GiB)
            expect(planned_device.max_size).to eq(8.GiB)
          end
        end

        context "when it is planning a device with btrfs filesystem" do
          let(:fs_type) { :btrfs }

          let(:btrfs_volume) do
            volume.merge(
              "snapshots"               => snapshots,
              "snapshots_size"          => snapshots_size.to_s,
              "btrfs_default_subvolume" => btrfs_default_subvolume,
              "subvolumes"              => subvolumes
            )
          end

          let(:volumes) { [btrfs_volume] }

          let(:snapshots) { false }

          let(:snapshots_size) { 1.GiB }

          let(:btrfs_default_subvolume) { "@" }

          let(:subvolumes) { [] }

          it "sets default_subvolume value according to the btrfs_default_subvolume in <volume> entry" do
            expect(planned_device.default_subvolume).to eq(btrfs_default_subvolume)
          end

          context "and snapshots is not active" do
            let(:snapshots) { false }

            it "sets snapshots value to false" do
              expect(planned_device.snapshots?).to eq(false)
            end

            it "uses normal sizes" do
              expect(planned_device.min_size).to eq(desired_size)
              expect(planned_device.max_size).to eq(max_size)
            end
          end

          context "and snapshots is active" do
            let(:snapshots) { true }

            it "sets snapshots value to true" do
              expect(planned_device.snapshots?).to eq(true)
            end

            context "and snapshots_size is a number" do
              let(:snapshots_size) { 100 }

              xit "considers it a percentage and increases the min and max sizes" do
                expect(planned_device.min_size).to eq(desired_size * 2)
                expect(planned_device.max_size).to eq(max_size * 2)
              end
            end

            context "and snapshots_size is a disk size" do
              let(:snapshots_size) { 1.GiB }

              it "increases the min and max sizes" do
                expect(planned_device.min_size).to eq(desired_size + snapshots_size)
                expect(planned_device.max_size).to eq(max_size + snapshots_size)
              end
            end
          end

          context "and there are not subvolumes for the device" do
            let(:subvolumes) { [] }

            it "sets an empty list of subvolumes" do
              expect(planned_device.subvolumes).to be_empty
            end
          end

          context "and there are subvolumes for the device" do
            let(:subvolumes) { [{ "path" => "var" }, { "path" => "home" }] }

            context "and there are not shadowed subvolumes" do
              it "includes all subvolumes in the planned device" do
                expect(planned_device.subvolumes.map(&:path).sort).to eq(["home", "var"])
              end
            end

            context "and there are shadowed subvolumes" do
              let(:home_volume) do
                {
                  "proposed"     => true,
                  "mount_point"  => "/home",
                  "fs_type"      => :xfs,
                  "desired_size" => "10 GiB",
                  "min_size"     => "5 GiB",
                  "max_size"     => "15 GiB",
                  "weight"       => 100
                }
              end

              let(:volumes) { [btrfs_volume, home_volume] }

              it "includes only the non-subvolumes in the planned device" do
                expect(planned_device.subvolumes.map(&:path)).to eq(["var"])
              end
            end
          end
        end

        context "when it is planning a root device" do
          let(:mount_point) { "/" }

          before do
            settings.root_device = root_device
          end

          context "and it is proposing a partition-based setup" do
            let(:lvm) { false }

            context "and a disk for root is indicated in the settings" do
              let(:root_device) { "/dev/sda" }

              it "plans a root device to be created in the expected disk" do
                expect(planned_device.disk).to eq(settings.root_device)
              end
            end

            context "and a disk for root is not indicated in the settings" do
              let(:root_device) { nil }

              it "plans a root device without a specific disk" do
                expect(planned_device.disk).to be_nil
              end
            end
          end
        end

        context "when it is planning a swap device" do
          let(:mount_point) { "swap" }
          let(:fs_type) { :swap }
          let(:desired_size) { 2.GiB }
          let(:min_size) { 1.GiB }
          let(:max_size) { 10.GiB }

          before do
            allow(devicegraph).to receive(:disk_devices).and_return([disk])
            allow(disk).to receive(:swap_partitions).and_return(swap_partitions)
          end

          let(:disk) { instance_double("Y2Storage::Disk", name: "/dev/sda") }

          let(:planned_swap) { planned_devices.select { |d| d.mount_point == "swap" } }

          context "and there is a swap partition big enough" do
            let(:swap_partitions) { [partition_double("/dev/sdaX", 3.GiB)] }

            context "if proposing an LVM setup" do
              let(:lvm) { true }

              context "without encryption" do
                let(:password) { nil }

                it "plans a plain logical volume with the right name and no swap reusing" do
                  expect(planned_swap).to contain_exactly(
                    an_object_having_attributes(
                      class:               Y2Storage::Planned::LvmLv,
                      encryption_password: nil,
                      logical_volume_name: "swap",
                      reuse:               nil
                    )
                  )
                end
              end

              context "with encryption" do
                let(:password) { "12345678" }

                # Encryption is performed at PV level, not at LV one
                it "plans a plain logical volume with the right name and no swap reusing" do
                  expect(planned_swap).to contain_exactly(
                    an_object_having_attributes(
                      class:               Y2Storage::Planned::LvmLv,
                      encryption_password: nil,
                      logical_volume_name: "swap",
                      reuse:               nil
                    )
                  )
                end
              end
            end

            context "if proposing a partition-based setup" do
              let(:lvm) { false }

              context "without encryption" do
                let(:password) { nil }

                it "plans a volume to reuse the existing swap and no new swap" do
                  expect(planned_swap).to contain_exactly(
                    an_object_having_attributes(reuse: "/dev/sdaX")
                  )
                end
              end

              context "with encryption" do
                let(:password) { "12345678" }

                it "plans a brand new swap volume and no swap reusing" do
                  expect(planned_swap).to contain_exactly(
                    an_object_having_attributes(reuse: nil)
                  )
                end
              end
            end
          end

          context "and there is no a swap partition big enough" do
            let(:swap_partitions) { [partition_double("/dev/sdaX", 1.GiB)] }
            let(:lvm) { false }

            it "plans a brand new swap volume and no swap reusing" do
              expect(planned_swap).to contain_exactly(an_object_having_attributes(reuse: nil))
            end
          end

          context "and there is no previous swap partition" do
            let(:swap_partitions) { [] }
            let(:lvm) { false }

            it "plans a brand new swap volume and no swap reusing" do
              expect(planned_swap).to contain_exactly(an_object_having_attributes(reuse: nil))
            end
          end
        end
      end
    end
  end
end
