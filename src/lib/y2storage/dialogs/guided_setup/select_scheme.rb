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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"

Yast.import "InstExtensionImage"
Yast.import "Popup"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog to select partitioning scheme.
      class SelectScheme < Base
        # Handler for :encryption check box.
        # @param focus [Boolean] whether password field should be focused
        def encryption_handler(focus: true)
          widget_update(:password, using_encryption?, attr: :Enabled)
          widget_update(:repeat_password, using_encryption?, attr: :Enabled)
          return unless focus && using_encryption?
          Yast::UI.SetFocus(Id(:password))
        end

      protected

        def close_dialog
          unload_cracklib
          super
        end

        def dialog_title
          _("Partitioning Scheme")
        end

        def dialog_content
          HSquash(
            VBox(
              Left(CheckBox(Id(:lvm), _("Enable Logical Volume Management (LVM)"))),
              VSpacing(1),
              Left(CheckBox(Id(:encryption), Opt(:notify), _("Enable Disk Encryption"))),
              VSpacing(0.2),
              Left(
                HBox(
                  HSpacing(2),
                  Password(Id(:password), _("Password"))
                )
              ),
              Left(
                HBox(
                  HSpacing(2),
                  Password(Id(:repeat_password), _("Verify Password"))
                )
              )
            )
          )
        end

        def initialize_widgets
          widget_update(:lvm, settings.use_lvm)
          widget_update(:encryption, settings.use_encryption)
          encryption_handler(focus: false)
          if settings.use_encryption
            widget_update(:password, settings.encryption_password)
            widget_update(:repeat_password, settings.encryption_password)
          end
        end

        def update_settings!
          settings.use_lvm = widget_value(:lvm)
          password = using_encryption? ? widget_value(:password) : nil
          settings.encryption_password = password
        end

      private

        PASS_MIN_SIZE = 5

        PASS_ALLOWED_CHARS =
          "0123456789" \
          "abcdefghijklmnopqrstuvwxyz" \
          "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
          "#* ,.;:._-+=!$%&/|?{[()]}@^\\<>"

        CRACKLIB_PACKAGE = "cracklib-dict-full.rpm"

        attr_reader :cracklib_loaded
        alias_method :cracklib_loaded?, :cracklib_loaded

        def valid?
          using_encryption? ? valid_password? : true
        end

        def using_encryption?
          widget_value(:encryption)
        end

        def valid_password?
          !password_blank? && password_match? &&
            password_correct? && password_strong?
        end

        def password_blank?
          return false unless widget_value(:password).empty?
          Yast::Report.Warning(_("A password is needed"))
          true
        end

        def password_match?
          return true if widget_value(:password) == widget_value(:repeat_password)
          Yast::Report.Warning(_("Password does not match"))
          false
        end

        def password_correct?
          correct = password_min_size? && password_allowed_chars?

          if !correct
            messages = [
              _("The password must have at least %d characters.") % PASS_MIN_SIZE,
              _("The password may only contain the following characters:\n" \
                "0..9, a..z, A..Z, and any of \"@#* ,.;:._-+=!$%&/|?{[()]}^\\<>\".")
            ]
            Yast::Report.Warning(messages.join("\n"))
          end

          correct
        end

        # Password is considered strong when cracklib returns an empty message.
        # User has the last word to decide whether to use a weak password.
        def password_strong?
          message = cracklib_message
          return true if message.empty?

          popup_text = [
            _("The password is too simple:"),
            message,
            "\n",
            _("Really use this password?")
          ].join("\n")

          Yast::Popup.AnyQuestion(
            "",
            popup_text,
            Yast::Label.YesButton,
            Yast::Label.NoButton,
            :focus_yes
          )
        end

        def password_min_size?
          password.size >= PASS_MIN_SIZE
        end

        def password_allowed_chars?
          password.split(//).all? { |c| PASS_ALLOWED_CHARS.include?(c) }
        end

        # Checks password strength using cracklib.
        # @return[String] crack lib message, empty ("") if successful or
        # cracklib cannot be loaded.
        def cracklib_message
          load_cracklib
          return "" unless cracklib_loaded?
          Yast::SCR.Execute(Yast::Path.new(".crack"), password)
        end

        def load_cracklib
          return true if cracklib_loaded?
          message = "Loading to memory package #{CRACKLIB_PACKAGE}"
          loaded = Yast::InstExtensionImage.LoadExtension(CRACKLIB_PACKAGE, message)
          log.warn("WARNING: Failed to load cracklib. Please check logs.") unless loaded
          @cracklib_loaded = loaded
        end

        def unload_cracklib
          return false unless cracklib_loaded?
          message = "Removing from memory package #{CRACKLIB_PACKAGE}"
          unloaded = Yast::InstExtensionImage.UnLoadExtension(CRACKLIB_PACKAGE, message)
          log.warn("Warning: Failed to remove cracklib. Please check logs.") unless unloaded
          @cracklib_loaded = !unloaded
        end

        def password
          widget_value(:password)
        end
      end
    end
  end
end
