# Debugging Scripts to Remove

These scripts were created for one-time debugging/troubleshooting and can be safely deleted.

## Deployment Debugging (from AppleMapsService deployment session)
- check_apple_maps_service_exists.sh
- check_build_progress.sh
- check_container_failure.sh
- check_docker_image_setup.sh
- check_docker_mounts.sh
- check_env_vars.sh
- check_production_deployment.sh
- check_worker_status.sh
- diagnose_startup.sh
- get_complete_logs.sh
- get_full_logs.sh
- quick_check_bins.sh
- search_maps_error_all.sh
- show_env_format.sh
- troubleshoot_deployment.sh
- verify_maps_deployment.sh

## Bot State Debugging
- analyze_bot_state_at_error.sh
- check_bot_applepay_detailed.sh
- check_bot_inbox.rb
- check_bot_logs.sh
- check_bot_status.rb
- check_conversation_history.sh
- check_error_time_logs.sh
- check_last_40.sh
- check_live_messages.sh
- check_maps_error.sh
- check_maps_service_file.sh
- check_message_details.rb
- check_most_recent.sh
- debug_bot.rb
- debug_bot_behavior.sh
- test_bot_directly.rb

## Template/Image Debugging
- check_and_fix_templates.rb
- check_inbox_6_channel.rb
- check_inbox_6_payload.rb
- check_inbox_summary_images.rb
- check_old_numbered_identifiers.rb
- check_storage_strategy.rb
- check_template_355_images.rb
- check_template_fields.sh
- check_template_images_array.rb
- check_templates.rb
- check_unknown_templates.rb
- debug_content_block_attributes.rb
- debug_forms.rb
- debug_menu_payload.rb
- debug_messages_png.rb
- debug_template_321_send.rb
- debug_template_343_send.rb
- debug_template_343_structure.rb
- debug_template_366_save.rb
- debug_template_categories.rb
- debug_template_structure.rb
- diagnose_and_map_images.rb
- diagnose_form_conversion.rb
- diagnose_guitar_list_picker_images.rb
- diagnose_identifier_4.rb
- diagnose_template_images.rb
- examine_numeric_images.rb
- export_numeric_images.rb
- find_correct_image_source.rb
- find_guitar_images.rb
- find_menu_icons_all_inboxes.rb
- find_original_identifiers.rb
- inspect_and_clean_template_343.rb
- inspect_image.sh
- inspect_shared_images_1_3.rb
- inspect_template_343_images.rb
- show_all_images_detailed.rb
- show_form_343_structure.rb
- show_inbox_5_images.rb
- show_template_321_structure.rb
- simple_template_check.sh
- template_check.rb
- template_diagnostic.sh
- verify_template_343_images.rb
- verify_template_structure.rb

## Apple Pay Debugging
- check_applepay_issue.sh
- check_applepay_logs.sh
- check_channel_5_apple_pay.rb
- cleanup_applepay_domain.sh
- debug_key_parsing.rb
- diagnose_merchant_id.sh
- find_merchant_id_config.rb
- fix_applepay_config.sh
- test-apple-pay-merchant-session.rb
- test_applepay_direct.sh
- test_apple_pay_service.rb
- verify_apple_pay_config.rb

## One-time Fixes/Migrations
- copy_messages_png_to_inbox_6.rb
- copy_missing_guitar_image.rb
- delete_inbox_6_images_1_13.rb
- delete_old_numbered_identifiers.rb
- ensure_shared_images_in_all_inboxes.rb
- final_fix_template_366.rb
- fix_aha19_image_identifiers.rb
- fix_guitar_form_content_block.rb
- fix_guitar_list_picker_321_images.rb
- fix_menu_item_images.rb
- fix_migrated_templates.rb
- fix_received_message_image_321.rb
- fix_shared_images_from_template.rb
- fix_storage_strategy.rb
- fix_summary_images_1_3.rb
- fix_summary_list_picker_images_format.rb
- fix_template_343_add_title.rb
- fix_template_343_final.rb
- fix_template_343_final_v2.rb
- fix_template_343_image_identifiers.rb
- fix_template_366_images.rb
- fix_template_status_production.sh
- fix_template_use_cases.rb
- fix_with_embedded_images.rb
- manual_image_mapping.rb
- map_blob_filenames_to_identifiers.rb
- rollback_and_fix_correctly.rb
- sync_all_guitar_images.rb
- sync_identifier_4.rb
- update_received_image_to_4.rb
- update_template_355_icons.rb
- update_template_355_with_summary_icons.rb
- upload_guitar_images.rb
- upload_guitar_images_inbox_6.rb
- upload_summary_images_to_shared.rb

## Test/Debug Scripts
- debug_apple_form_send.rb
- test_fetch_images.rb
- test_image_extraction.rb
- test_jwt_generation.rb
- test_log_sanitization.rb
- test_nil_log_filtering.rb
- test_template_323.rb
- test_template_343_render.rb
- test_timeslot_preservation.rb
- test_timeslots_formatting.rb
- trace_case_transformer.rb
- verify_fix_template_343_pages.rb
- verify_image_identifiers_1_13.rb
- verify_log_sanitization.rb
- verify_ui_visibility.rb

## Diagnostic Scripts
- diagnose-amb-logs.sh
- diagnose-conversation-visibility.sh
- diagnose_apple_maps_key.rb
- diagnose_apple_messages.rb
- diagnose_inbox_usage.rb
- run_diagnostic.sh
- run_template_diagnostic.sh

## Docker Build Debugging (from deployment troubleshooting)
- build_low_memory.sh
- build_on_production.sh
- quick_rebuild.sh
- recover_from_oom.sh
- sync_and_rebuild.sh
- fix_docker_compose_env.sh
- reload_containers_with_env.sh
- restart_containers_for_code.sh

## Verification Scripts (one-time checks)
- verify_acoustic_house_bot.rb
- verify_and_fix_acoustic_house_templates.rb
- verify_image_migration.rb
- verify_shared_images.rb
- verify_template_343_complete.rb
- verify_template_attachment_tests.rb
- validate_template_343_complete.rb
- validate_template_attachment_tests.rb
- run_verify_ui.rb

---

## Summary
**Total scripts to remove: ~160+**

These can be safely deleted with:
```bash
cd script/
# Review the list first, then remove
rm -i <script_name>
```

Or create a cleanup script to remove all at once.
