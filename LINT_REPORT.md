# Linter Error Report (Static Analysis)
**Generated at:** 2026-01-09 03:17:10

このファイルは \lutter analyze\ の実行結果です。
**Status**: Latest analysis result.

```text
Analyzing my_web_app...                                         

   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:42:11 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:42:52 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:43:14 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:90:11 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:90:52 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:93:27 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:94:22 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_secretary_page.dart:95:42 - avoid_dynamic_calls
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\ai_secretary_page.dart:339:17 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\ai_secretary_page.dart:339:23 - deprecated_member_use
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:45:29 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:61:29 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:61:58 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:67:32 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:93:13 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:96:29 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:101:53 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:104:39 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:106:20 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:109:15 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:117:36 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:120:51 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:122:13 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:174:38 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:175:35 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\ai_status_page.dart:176:39 - avoid_dynamic_calls
   info - Missing a required trailing comma - lib\pages\cfo_office_page.dart:45:34 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\cho_office_page.dart:45:34 - require_trailing_commas
warning - The value of the field '_isLoading' isn't used - lib\pages\chro_page.dart:17:8 - unused_field
   info - Don't use 'BuildContext's across async gaps - lib\pages\chro_page.dart:95:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\pages\chro_page.dart:99:28 - use_build_context_synchronously
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:123:11 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:129:17 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:130:27 - avoid_dynamic_calls
   info - Don't use 'BuildContext's across async gaps - lib\pages\chro_page.dart:135:28 - use_build_context_synchronously
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:160:21 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:264:25 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\chro_page.dart:269:26 - avoid_dynamic_calls
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\cmo_office_page.dart:49:5 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\cmo_office_page.dart:49:11 - deprecated_member_use
  error - The value of the local variable 'streak' isn't used - lib\pages\cmo_office_page.dart:54:11 - unused_local_variable
  error - The value of the local variable 'points' isn't used - lib\pages\cmo_office_page.dart:55:11 - unused_local_variable
  error - The value of the local variable 'level' isn't used - lib\pages\cmo_office_page.dart:56:11 - unused_local_variable
  error - Unterminated string literal - lib\pages\cmo_office_page.dart:71:81 - unterminated_string_literal
  error - Expected to find ',' - lib\pages\cmo_office_page.dart:72:17 - expected_token
  error - The argument type 'SizedBox' can't be assigned to the parameter type 'IconData'.  - lib\pages\cmo_office_page.dart:72:17 - argument_type_not_assignable
  error - The argument type 'Widget' can't be assigned to the parameter type 'Color'.  - lib\pages\cmo_office_page.dart:73:17 - argument_type_not_assignable
  error - Too many positional arguments: 4 expected, but 5 found - lib\pages\cmo_office_page.dart:81:17 - extra_positional_arguments
   info - Missing a required trailing comma - lib\pages\cmo_office_page.dart:89:15 - require_trailing_commas
  error - Expected to find ')' - lib\pages\cmo_office_page.dart:89:15 - expected_token
   info - Method invocation or property access on a 'dynamic' target - lib\pages\cmo_page.dart:57:11 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\cmo_page.dart:57:52 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\cmo_page.dart:61:27 - avoid_dynamic_calls
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\cmo_page.dart:80:5 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\cmo_page.dart:80:11 - deprecated_member_use
  error - The value of the local variable 'level' isn't used - lib\pages\emergency_meeting_page.dart:46:13 - unused_local_variable
   info - Use 'const' for final variables initialized to a constant value - lib\pages\emergency_meeting_page.dart:49:7 - prefer_const_declarations
   info - Unnecessary use of double quotes - lib\pages\emergency_meeting_page.dart:49:29 - prefer_single_quotes
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:49:29 - expected_token
  error - Illegal character '32202' - lib\pages\emergency_meeting_page.dart:50:1 - illegal_character
  error - Undefined class '緊急役員会議を開催します。以下の【全部署の現状データ】に基づき、厳しく現状を分析し、報告してください。' - lib\pages\emergency_meeting_page.dart:50:1 - undefined_class
  error - Illegal character '24613' - lib\pages\emergency_meeting_page.dart:50:2 - illegal_character
  error - Illegal character '24441' - lib\pages\emergency_meeting_page.dart:50:3 - illegal_character
  error - Illegal character '21729' - lib\pages\emergency_meeting_page.dart:50:4 - illegal_character
  error - Illegal character '20250' - lib\pages\emergency_meeting_page.dart:50:5 - illegal_character
  error - Illegal character '35696' - lib\pages\emergency_meeting_page.dart:50:6 - illegal_character
  error - Illegal character '12434' - lib\pages\emergency_meeting_page.dart:50:7 - illegal_character
  error - Illegal character '38283' - lib\pages\emergency_meeting_page.dart:50:8 - illegal_character
  error - Illegal character '20652' - lib\pages\emergency_meeting_page.dart:50:9 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:50:10 - illegal_character
  error - Illegal character '12414' - lib\pages\emergency_meeting_page.dart:50:11 - illegal_character
  error - Illegal character '12377' - lib\pages\emergency_meeting_page.dart:50:12 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:50:13 - illegal_character
  error - Illegal character '20197' - lib\pages\emergency_meeting_page.dart:50:14 - illegal_character
  error - Illegal character '19979' - lib\pages\emergency_meeting_page.dart:50:15 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:50:16 - illegal_character
  error - Illegal character '12304' - lib\pages\emergency_meeting_page.dart:50:17 - illegal_character
  error - Illegal character '20840' - lib\pages\emergency_meeting_page.dart:50:18 - illegal_character
  error - Illegal character '37096' - lib\pages\emergency_meeting_page.dart:50:19 - illegal_character
  error - Illegal character '32626' - lib\pages\emergency_meeting_page.dart:50:20 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:50:21 - illegal_character
  error - Illegal character '29694' - lib\pages\emergency_meeting_page.dart:50:22 - illegal_character
  error - Illegal character '29366' - lib\pages\emergency_meeting_page.dart:50:23 - illegal_character
  error - Illegal character '12487' - lib\pages\emergency_meeting_page.dart:50:24 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:50:25 - illegal_character
  error - Illegal character '12479' - lib\pages\emergency_meeting_page.dart:50:26 - illegal_character
  error - Illegal character '12305' - lib\pages\emergency_meeting_page.dart:50:27 - illegal_character
  error - Illegal character '12395' - lib\pages\emergency_meeting_page.dart:50:28 - illegal_character
  error - Illegal character '22522' - lib\pages\emergency_meeting_page.dart:50:29 - illegal_character
  error - Illegal character '12389' - lib\pages\emergency_meeting_page.dart:50:30 - illegal_character
  error - Illegal character '12365' - lib\pages\emergency_meeting_page.dart:50:31 - illegal_character
  error - Illegal character '12289' - lib\pages\emergency_meeting_page.dart:50:32 - illegal_character
  error - Illegal character '21427' - lib\pages\emergency_meeting_page.dart:50:33 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:50:34 - illegal_character
  error - Illegal character '12367' - lib\pages\emergency_meeting_page.dart:50:35 - illegal_character
  error - Illegal character '29694' - lib\pages\emergency_meeting_page.dart:50:36 - illegal_character
  error - Illegal character '29366' - lib\pages\emergency_meeting_page.dart:50:37 - illegal_character
  error - Illegal character '12434' - lib\pages\emergency_meeting_page.dart:50:38 - illegal_character
  error - Illegal character '20998' - lib\pages\emergency_meeting_page.dart:50:39 - illegal_character
  error - Illegal character '26512' - lib\pages\emergency_meeting_page.dart:50:40 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:50:41 - illegal_character
  error - Illegal character '12289' - lib\pages\emergency_meeting_page.dart:50:42 - illegal_character
  error - Illegal character '22577' - lib\pages\emergency_meeting_page.dart:50:43 - illegal_character
  error - Illegal character '21578' - lib\pages\emergency_meeting_page.dart:50:44 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:50:45 - illegal_character
  error - Illegal character '12390' - lib\pages\emergency_meeting_page.dart:50:46 - illegal_character
  error - Illegal character '12367' - lib\pages\emergency_meeting_page.dart:50:47 - illegal_character
  error - Illegal character '12384' - lib\pages\emergency_meeting_page.dart:50:48 - illegal_character
  error - Illegal character '12373' - lib\pages\emergency_meeting_page.dart:50:49 - illegal_character
  error - Illegal character '12356' - lib\pages\emergency_meeting_page.dart:50:50 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:50:51 - illegal_character
   info - The variable name '最後にCSOがこれらを統合し、CEO' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:51:1 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:51:1 - expected_token
  error - Illegal character '26368' - lib\pages\emergency_meeting_page.dart:51:1 - illegal_character
  error - The value of the local variable '最後にCSOがこれらを統合し、CEO' isn't used - lib\pages\emergency_meeting_page.dart:51:1 - unused_local_variable
  error - Illegal character '24460' - lib\pages\emergency_meeting_page.dart:51:2 - illegal_character
  error - Illegal character '12395' - lib\pages\emergency_meeting_page.dart:51:3 - illegal_character
  error - Illegal character '12364' - lib\pages\emergency_meeting_page.dart:51:7 - illegal_character
  error - Illegal character '12371' - lib\pages\emergency_meeting_page.dart:51:8 - illegal_character
  error - Illegal character '12428' - lib\pages\emergency_meeting_page.dart:51:9 - illegal_character
  error - Illegal character '12425' - lib\pages\emergency_meeting_page.dart:51:10 - illegal_character
  error - Illegal character '12434' - lib\pages\emergency_meeting_page.dart:51:11 - illegal_character
  error - Illegal character '32113' - lib\pages\emergency_meeting_page.dart:51:12 - illegal_character
  error - Illegal character '21512' - lib\pages\emergency_meeting_page.dart:51:13 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:51:14 - illegal_character
  error - Illegal character '12289' - lib\pages\emergency_meeting_page.dart:51:15 - illegal_character
  error - Illegal character '12518' - lib\pages\emergency_meeting_page.dart:51:20 - illegal_character
  error - Undefined name 'ユーザー' - lib\pages\emergency_meeting_page.dart:51:20 - undefined_identifier
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:51:21 - illegal_character
  error - Illegal character '12470' - lib\pages\emergency_meeting_page.dart:51:22 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:51:23 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:51:24 - expected_token
  error - Illegal character '12364' - lib\pages\emergency_meeting_page.dart:51:25 - illegal_character
  error - Undefined class 'が今週末にとるべき具体的な行動プランを3つ提案してください。' - lib\pages\emergency_meeting_page.dart:51:25 - undefined_class
  error - Illegal character '20170' - lib\pages\emergency_meeting_page.dart:51:26 - illegal_character
  error - Illegal character '36913' - lib\pages\emergency_meeting_page.dart:51:27 - illegal_character
  error - Illegal character '26411' - lib\pages\emergency_meeting_page.dart:51:28 - illegal_character
  error - Illegal character '12395' - lib\pages\emergency_meeting_page.dart:51:29 - illegal_character
  error - Illegal character '12392' - lib\pages\emergency_meeting_page.dart:51:30 - illegal_character
  error - Illegal character '12427' - lib\pages\emergency_meeting_page.dart:51:31 - illegal_character
  error - Illegal character '12409' - lib\pages\emergency_meeting_page.dart:51:32 - illegal_character
  error - Illegal character '12365' - lib\pages\emergency_meeting_page.dart:51:33 - illegal_character
  error - Illegal character '20855' - lib\pages\emergency_meeting_page.dart:51:34 - illegal_character
  error - Illegal character '20307' - lib\pages\emergency_meeting_page.dart:51:35 - illegal_character
  error - Illegal character '30340' - lib\pages\emergency_meeting_page.dart:51:36 - illegal_character
  error - Illegal character '12394' - lib\pages\emergency_meeting_page.dart:51:37 - illegal_character
  error - Illegal character '34892' - lib\pages\emergency_meeting_page.dart:51:38 - illegal_character
  error - Illegal character '21205' - lib\pages\emergency_meeting_page.dart:51:39 - illegal_character
  error - Illegal character '12503' - lib\pages\emergency_meeting_page.dart:51:40 - illegal_character
  error - Illegal character '12521' - lib\pages\emergency_meeting_page.dart:51:41 - illegal_character
  error - Illegal character '12531' - lib\pages\emergency_meeting_page.dart:51:42 - illegal_character
  error - Illegal character '12434' - lib\pages\emergency_meeting_page.dart:51:43 - illegal_character
  error - Illegal character '12388' - lib\pages\emergency_meeting_page.dart:51:45 - illegal_character
  error - Illegal character '25552' - lib\pages\emergency_meeting_page.dart:51:46 - illegal_character
  error - Illegal character '26696' - lib\pages\emergency_meeting_page.dart:51:47 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:51:48 - illegal_character
  error - Illegal character '12390' - lib\pages\emergency_meeting_page.dart:51:49 - illegal_character
  error - Illegal character '12367' - lib\pages\emergency_meeting_page.dart:51:50 - illegal_character
  error - Illegal character '12384' - lib\pages\emergency_meeting_page.dart:51:51 - illegal_character
  error - Illegal character '12373' - lib\pages\emergency_meeting_page.dart:51:52 - illegal_character
  error - Illegal character '12356' - lib\pages\emergency_meeting_page.dart:51:53 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:51:54 - illegal_character
   info - The variable name '【現状データ】' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:53:1 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:53:1 - expected_token
  error - Illegal character '12304' - lib\pages\emergency_meeting_page.dart:53:1 - illegal_character
  error - The value of the local variable '【現状データ】' isn't used - lib\pages\emergency_meeting_page.dart:53:1 - unused_local_variable
  error - Illegal character '29694' - lib\pages\emergency_meeting_page.dart:53:2 - illegal_character
  error - Illegal character '29366' - lib\pages\emergency_meeting_page.dart:53:3 - illegal_character
  error - Illegal character '12487' - lib\pages\emergency_meeting_page.dart:53:4 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:53:5 - illegal_character
  error - Illegal character '12479' - lib\pages\emergency_meeting_page.dart:53:6 - illegal_character
  error - Illegal character '12305' - lib\pages\emergency_meeting_page.dart:53:7 - illegal_character
  error - Undefined name 'CEO' - lib\pages\emergency_meeting_page.dart:54:2 - undefined_identifier
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:54:5 - expected_token
warning - The label 'ユーザーID' isn't used - lib\pages\emergency_meeting_page.dart:54:7 - unused_label
  error - Illegal character '12518' - lib\pages\emergency_meeting_page.dart:54:7 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:54:8 - illegal_character
  error - Illegal character '12470' - lib\pages\emergency_meeting_page.dart:54:9 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:54:10 - illegal_character
  error - Undefined name 'CKO' - lib\pages\emergency_meeting_page.dart:55:2 - undefined_identifier
  error - Illegal character '30693' - lib\pages\emergency_meeting_page.dart:55:6 - illegal_character
  error - Undefined name '知識' - lib\pages\emergency_meeting_page.dart:55:6 - undefined_identifier
  error - Illegal character '35672' - lib\pages\emergency_meeting_page.dart:55:7 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:55:8 - expected_token
warning - The label '蓄積メモ数' isn't used - lib\pages\emergency_meeting_page.dart:55:10 - unused_label
  error - Illegal character '33988' - lib\pages\emergency_meeting_page.dart:55:10 - illegal_character
  error - Illegal character '31309' - lib\pages\emergency_meeting_page.dart:55:11 - illegal_character
  error - Illegal character '12513' - lib\pages\emergency_meeting_page.dart:55:12 - illegal_character
  error - Illegal character '12514' - lib\pages\emergency_meeting_page.dart:55:13 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:55:14 - illegal_character
  error - Local variable 'noteCount' can't be referenced before it is declared - lib\pages\emergency_meeting_page.dart:55:17 - referenced_before_declaration
   info - The variable name '件' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:55:27 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:55:27 - expected_token
  error - Illegal character '20214' - lib\pages\emergency_meeting_page.dart:55:27 - illegal_character
  error - The value of the local variable '件' isn't used - lib\pages\emergency_meeting_page.dart:55:27 - unused_local_variable
  error - Undefined name 'CFO' - lib\pages\emergency_meeting_page.dart:56:2 - undefined_identifier
  error - Illegal character '36001' - lib\pages\emergency_meeting_page.dart:56:6 - illegal_character
  error - Undefined name '財務' - lib\pages\emergency_meeting_page.dart:56:6 - undefined_identifier
  error - Illegal character '21209' - lib\pages\emergency_meeting_page.dart:56:7 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:56:8 - expected_token
warning - The label '登録サブスク数' isn't used - lib\pages\emergency_meeting_page.dart:56:10 - unused_label
  error - Illegal character '30331' - lib\pages\emergency_meeting_page.dart:56:10 - illegal_character
  error - Illegal character '37682' - lib\pages\emergency_meeting_page.dart:56:11 - illegal_character
  error - Illegal character '12469' - lib\pages\emergency_meeting_page.dart:56:12 - illegal_character
  error - Illegal character '12502' - lib\pages\emergency_meeting_page.dart:56:13 - illegal_character
  error - Illegal character '12473' - lib\pages\emergency_meeting_page.dart:56:14 - illegal_character
  error - Illegal character '12463' - lib\pages\emergency_meeting_page.dart:56:15 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:56:16 - illegal_character
  error - Local variable 'subCount' can't be referenced before it is declared - lib\pages\emergency_meeting_page.dart:56:19 - referenced_before_declaration
   info - The variable name '件' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:56:28 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:56:28 - expected_token
  error - Illegal character '20214' - lib\pages\emergency_meeting_page.dart:56:28 - illegal_character
  error - The value of the local variable '件' isn't used - lib\pages\emergency_meeting_page.dart:56:28 - unused_local_variable
  error - Illegal character '12467' - lib\pages\emergency_meeting_page.dart:56:31 - illegal_character
  error - Undefined name 'コスト意識の確認' - lib\pages\emergency_meeting_page.dart:56:31 - undefined_identifier
  error - Illegal character '12473' - lib\pages\emergency_meeting_page.dart:56:32 - illegal_character
  error - Illegal character '12488' - lib\pages\emergency_meeting_page.dart:56:33 - illegal_character
  error - Illegal character '24847' - lib\pages\emergency_meeting_page.dart:56:34 - illegal_character
  error - Illegal character '35672' - lib\pages\emergency_meeting_page.dart:56:35 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:56:36 - illegal_character
  error - Illegal character '30906' - lib\pages\emergency_meeting_page.dart:56:37 - illegal_character
  error - Illegal character '35469' - lib\pages\emergency_meeting_page.dart:56:38 - illegal_character
  error - Undefined name 'CHRO' - lib\pages\emergency_meeting_page.dart:57:2 - undefined_identifier
  error - Illegal character '20154' - lib\pages\emergency_meeting_page.dart:57:7 - illegal_character
  error - Undefined name '人事' - lib\pages\emergency_meeting_page.dart:57:7 - undefined_identifier
  error - Illegal character '20107' - lib\pages\emergency_meeting_page.dart:57:8 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:57:9 - expected_token
warning - The label '獲得ポイント' isn't used - lib\pages\emergency_meeting_page.dart:57:11 - unused_label
  error - Illegal character '29554' - lib\pages\emergency_meeting_page.dart:57:11 - illegal_character
  error - Illegal character '24471' - lib\pages\emergency_meeting_page.dart:57:12 - illegal_character
  error - Illegal character '12509' - lib\pages\emergency_meeting_page.dart:57:13 - illegal_character
  error - Illegal character '12452' - lib\pages\emergency_meeting_page.dart:57:14 - illegal_character
  error - Illegal character '12531' - lib\pages\emergency_meeting_page.dart:57:15 - illegal_character
  error - Illegal character '12488' - lib\pages\emergency_meeting_page.dart:57:16 - illegal_character
  error - Local variable 'points' can't be referenced before it is declared - lib\pages\emergency_meeting_page.dart:57:19 - referenced_before_declaration
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:57:26 - expected_token
  error - The value of the local variable 'pt' isn't used - lib\pages\emergency_meeting_page.dart:57:26 - unused_local_variable
  error - Undefined name 'Lv' - lib\pages\emergency_meeting_page.dart:57:30 - undefined_identifier
  error - Undefined name 'CMO' - lib\pages\emergency_meeting_page.dart:58:2 - undefined_identifier
  error - Illegal character '24066' - lib\pages\emergency_meeting_page.dart:58:6 - illegal_character
  error - Undefined name '市場' - lib\pages\emergency_meeting_page.dart:58:6 - undefined_identifier
  error - Illegal character '22580' - lib\pages\emergency_meeting_page.dart:58:7 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:58:8 - expected_token
  error - Illegal character '12456' - lib\pages\emergency_meeting_page.dart:58:10 - illegal_character
  error - The method 'エンゲージメント' isn't defined for the type '_EmergencyMeetingPageState' - lib\pages\emergency_meeting_page.dart:58:10 - undefined_method
  error - Illegal character '12531' - lib\pages\emergency_meeting_page.dart:58:11 - illegal_character
  error - Illegal character '12466' - lib\pages\emergency_meeting_page.dart:58:12 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:58:13 - illegal_character
  error - Illegal character '12472' - lib\pages\emergency_meeting_page.dart:58:14 - illegal_character
  error - Illegal character '12513' - lib\pages\emergency_meeting_page.dart:58:15 - illegal_character
  error - Illegal character '12531' - lib\pages\emergency_meeting_page.dart:58:16 - illegal_character
  error - Illegal character '12488' - lib\pages\emergency_meeting_page.dart:58:17 - illegal_character
  error - Illegal character '32153' - lib\pages\emergency_meeting_page.dart:58:19 - illegal_character
  error - Undefined name '継続日数' - lib\pages\emergency_meeting_page.dart:58:19 - undefined_identifier
  error - Illegal character '32154' - lib\pages\emergency_meeting_page.dart:58:20 - illegal_character
  error - Illegal character '26085' - lib\pages\emergency_meeting_page.dart:58:21 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:58:22 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:58:23 - expected_token
  error - Expected an identifier - lib\pages\emergency_meeting_page.dart:58:24 - missing_identifier
  error - Unexpected text ':' - lib\pages\emergency_meeting_page.dart:58:24 - unexpected_token
  error - Local variable 'streak' can't be referenced before it is declared - lib\pages\emergency_meeting_page.dart:58:26 - referenced_before_declaration
   info - The variable name '日' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:58:33 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:58:33 - expected_token
  error - Illegal character '26085' - lib\pages\emergency_meeting_page.dart:58:33 - illegal_character
  error - The value of the local variable '日' isn't used - lib\pages\emergency_meeting_page.dart:58:33 - unused_local_variable
  error - Undefined name 'CHO' - lib\pages\emergency_meeting_page.dart:59:2 - undefined_identifier
  error - Illegal character '20581' - lib\pages\emergency_meeting_page.dart:59:6 - illegal_character
  error - Undefined name '健康' - lib\pages\emergency_meeting_page.dart:59:6 - undefined_identifier
  error - Illegal character '24247' - lib\pages\emergency_meeting_page.dart:59:7 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:59:8 - expected_token
warning - The label '健康ログ記録数' isn't used - lib\pages\emergency_meeting_page.dart:59:10 - unused_label
  error - Illegal character '20581' - lib\pages\emergency_meeting_page.dart:59:10 - illegal_character
  error - Illegal character '24247' - lib\pages\emergency_meeting_page.dart:59:11 - illegal_character
  error - Illegal character '12525' - lib\pages\emergency_meeting_page.dart:59:12 - illegal_character
  error - Illegal character '12464' - lib\pages\emergency_meeting_page.dart:59:13 - illegal_character
  error - Illegal character '35352' - lib\pages\emergency_meeting_page.dart:59:14 - illegal_character
  error - Illegal character '37682' - lib\pages\emergency_meeting_page.dart:59:15 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:59:16 - illegal_character
  error - Local variable 'healthCount' can't be referenced before it is declared - lib\pages\emergency_meeting_page.dart:59:19 - referenced_before_declaration
   info - The variable name '件' isn't a lowerCamelCase identifier - lib\pages\emergency_meeting_page.dart:59:31 - non_constant_identifier_names
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:59:31 - expected_token
  error - Illegal character '20214' - lib\pages\emergency_meeting_page.dart:59:31 - illegal_character
  error - The value of the local variable '件' isn't used - lib\pages\emergency_meeting_page.dart:59:31 - unused_local_variable
  error - The expression doesn't evaluate to a function, so it can't be invoked - lib\pages\emergency_meeting_page.dart:60:1 - invocation_of_non_function_expression
  error - Undefined name 'CSO' - lib\pages\emergency_meeting_page.dart:60:2 - undefined_identifier
  error - Illegal character '25126' - lib\pages\emergency_meeting_page.dart:60:6 - illegal_character
  error - Undefined name '戦略' - lib\pages\emergency_meeting_page.dart:60:6 - undefined_identifier
  error - Illegal character '30053' - lib\pages\emergency_meeting_page.dart:60:7 - illegal_character
  error - Illegal character '26029' - lib\pages\emergency_meeting_page.dart:60:11 - illegal_character
  error - Undefined name '断捨離データは別途確認' - lib\pages\emergency_meeting_page.dart:60:11 - undefined_identifier
  error - Illegal character '25448' - lib\pages\emergency_meeting_page.dart:60:12 - illegal_character
  error - Illegal character '38626' - lib\pages\emergency_meeting_page.dart:60:13 - illegal_character
  error - Illegal character '12487' - lib\pages\emergency_meeting_page.dart:60:14 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:60:15 - illegal_character
  error - Illegal character '12479' - lib\pages\emergency_meeting_page.dart:60:16 - illegal_character
  error - Illegal character '12399' - lib\pages\emergency_meeting_page.dart:60:17 - illegal_character
  error - Illegal character '21029' - lib\pages\emergency_meeting_page.dart:60:18 - illegal_character
  error - Illegal character '36884' - lib\pages\emergency_meeting_page.dart:60:19 - illegal_character
  error - Illegal character '30906' - lib\pages\emergency_meeting_page.dart:60:20 - illegal_character
  error - Illegal character '35469' - lib\pages\emergency_meeting_page.dart:60:21 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:60:22 - expected_token
  error - Illegal character '12304' - lib\pages\emergency_meeting_page.dart:62:1 - illegal_character
  error - Undefined name '【発言ルール】' - lib\pages\emergency_meeting_page.dart:62:1 - undefined_identifier
  error - Illegal character '30330' - lib\pages\emergency_meeting_page.dart:62:2 - illegal_character
  error - Illegal character '35328' - lib\pages\emergency_meeting_page.dart:62:3 - illegal_character
  error - Illegal character '12523' - lib\pages\emergency_meeting_page.dart:62:4 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:62:5 - illegal_character
  error - Illegal character '12523' - lib\pages\emergency_meeting_page.dart:62:6 - illegal_character
  error - Illegal character '12305' - lib\pages\emergency_meeting_page.dart:62:7 - illegal_character
  error - Illegal character '21508' - lib\pages\emergency_meeting_page.dart:63:3 - illegal_character
  error - Undefined name '各役員は自分の専門分野のデータのみに言及すること。' - lib\pages\emergency_meeting_page.dart:63:3 - undefined_identifier
  error - Illegal character '24441' - lib\pages\emergency_meeting_page.dart:63:4 - illegal_character
  error - Illegal character '21729' - lib\pages\emergency_meeting_page.dart:63:5 - illegal_character
  error - Illegal character '12399' - lib\pages\emergency_meeting_page.dart:63:6 - illegal_character
  error - Illegal character '33258' - lib\pages\emergency_meeting_page.dart:63:7 - illegal_character
  error - Illegal character '20998' - lib\pages\emergency_meeting_page.dart:63:8 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:63:9 - illegal_character
  error - Illegal character '23554' - lib\pages\emergency_meeting_page.dart:63:10 - illegal_character
  error - Illegal character '38272' - lib\pages\emergency_meeting_page.dart:63:11 - illegal_character
  error - Illegal character '20998' - lib\pages\emergency_meeting_page.dart:63:12 - illegal_character
  error - Illegal character '37326' - lib\pages\emergency_meeting_page.dart:63:13 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:63:14 - illegal_character
  error - Illegal character '12487' - lib\pages\emergency_meeting_page.dart:63:15 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:63:16 - illegal_character
  error - Illegal character '12479' - lib\pages\emergency_meeting_page.dart:63:17 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:63:18 - illegal_character
  error - Illegal character '12415' - lib\pages\emergency_meeting_page.dart:63:19 - illegal_character
  error - Illegal character '12395' - lib\pages\emergency_meeting_page.dart:63:20 - illegal_character
  error - Illegal character '35328' - lib\pages\emergency_meeting_page.dart:63:21 - illegal_character
  error - Illegal character '21450' - lib\pages\emergency_meeting_page.dart:63:22 - illegal_character
  error - Illegal character '12377' - lib\pages\emergency_meeting_page.dart:63:23 - illegal_character
  error - Illegal character '12427' - lib\pages\emergency_meeting_page.dart:63:24 - illegal_character
  error - Illegal character '12371' - lib\pages\emergency_meeting_page.dart:63:25 - illegal_character
  error - Illegal character '12392' - lib\pages\emergency_meeting_page.dart:63:26 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:63:27 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:64:3 - illegal_character
  error - Undefined name '数字が少ない場合は「怠慢である」と厳しく指摘すること。' - lib\pages\emergency_meeting_page.dart:64:3 - undefined_identifier
  error - Illegal character '23383' - lib\pages\emergency_meeting_page.dart:64:4 - illegal_character
  error - Illegal character '12364' - lib\pages\emergency_meeting_page.dart:64:5 - illegal_character
  error - Illegal character '23569' - lib\pages\emergency_meeting_page.dart:64:6 - illegal_character
  error - Illegal character '12394' - lib\pages\emergency_meeting_page.dart:64:7 - illegal_character
  error - Illegal character '12356' - lib\pages\emergency_meeting_page.dart:64:8 - illegal_character
  error - Illegal character '22580' - lib\pages\emergency_meeting_page.dart:64:9 - illegal_character
  error - Illegal character '21512' - lib\pages\emergency_meeting_page.dart:64:10 - illegal_character
  error - Illegal character '12399' - lib\pages\emergency_meeting_page.dart:64:11 - illegal_character
  error - Illegal character '12300' - lib\pages\emergency_meeting_page.dart:64:12 - illegal_character
  error - Illegal character '24608' - lib\pages\emergency_meeting_page.dart:64:13 - illegal_character
  error - Illegal character '24930' - lib\pages\emergency_meeting_page.dart:64:14 - illegal_character
  error - Illegal character '12391' - lib\pages\emergency_meeting_page.dart:64:15 - illegal_character
  error - Illegal character '12354' - lib\pages\emergency_meeting_page.dart:64:16 - illegal_character
  error - Illegal character '12427' - lib\pages\emergency_meeting_page.dart:64:17 - illegal_character
  error - Illegal character '12301' - lib\pages\emergency_meeting_page.dart:64:18 - illegal_character
  error - Illegal character '12392' - lib\pages\emergency_meeting_page.dart:64:19 - illegal_character
  error - Illegal character '21427' - lib\pages\emergency_meeting_page.dart:64:20 - illegal_character
  error - Illegal character '12375' - lib\pages\emergency_meeting_page.dart:64:21 - illegal_character
  error - Illegal character '12367' - lib\pages\emergency_meeting_page.dart:64:22 - illegal_character
  error - Illegal character '25351' - lib\pages\emergency_meeting_page.dart:64:23 - illegal_character
  error - Illegal character '25688' - lib\pages\emergency_meeting_page.dart:64:24 - illegal_character
  error - Illegal character '12377' - lib\pages\emergency_meeting_page.dart:64:25 - illegal_character
  error - Illegal character '12427' - lib\pages\emergency_meeting_page.dart:64:26 - illegal_character
  error - Illegal character '12371' - lib\pages\emergency_meeting_page.dart:64:27 - illegal_character
  error - Illegal character '12392' - lib\pages\emergency_meeting_page.dart:64:28 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:64:29 - illegal_character
  error - Illegal character '25968' - lib\pages\emergency_meeting_page.dart:65:3 - illegal_character
  error - Undefined name '数字が多い場合は「リソース過多」のリスクを指摘すること。' - lib\pages\emergency_meeting_page.dart:65:3 - undefined_identifier
  error - Illegal character '23383' - lib\pages\emergency_meeting_page.dart:65:4 - illegal_character
  error - Illegal character '12364' - lib\pages\emergency_meeting_page.dart:65:5 - illegal_character
  error - Illegal character '22810' - lib\pages\emergency_meeting_page.dart:65:6 - illegal_character
  error - Illegal character '12356' - lib\pages\emergency_meeting_page.dart:65:7 - illegal_character
  error - Illegal character '22580' - lib\pages\emergency_meeting_page.dart:65:8 - illegal_character
  error - Illegal character '21512' - lib\pages\emergency_meeting_page.dart:65:9 - illegal_character
  error - Illegal character '12399' - lib\pages\emergency_meeting_page.dart:65:10 - illegal_character
  error - Illegal character '12300' - lib\pages\emergency_meeting_page.dart:65:11 - illegal_character
  error - Illegal character '12522' - lib\pages\emergency_meeting_page.dart:65:12 - illegal_character
  error - Illegal character '12477' - lib\pages\emergency_meeting_page.dart:65:13 - illegal_character
  error - Illegal character '12540' - lib\pages\emergency_meeting_page.dart:65:14 - illegal_character
  error - Illegal character '12473' - lib\pages\emergency_meeting_page.dart:65:15 - illegal_character
  error - Illegal character '36942' - lib\pages\emergency_meeting_page.dart:65:16 - illegal_character
  error - Illegal character '22810' - lib\pages\emergency_meeting_page.dart:65:17 - illegal_character
  error - Illegal character '12301' - lib\pages\emergency_meeting_page.dart:65:18 - illegal_character
  error - Illegal character '12398' - lib\pages\emergency_meeting_page.dart:65:19 - illegal_character
  error - Illegal character '12522' - lib\pages\emergency_meeting_page.dart:65:20 - illegal_character
  error - Illegal character '12473' - lib\pages\emergency_meeting_page.dart:65:21 - illegal_character
  error - Illegal character '12463' - lib\pages\emergency_meeting_page.dart:65:22 - illegal_character
  error - Illegal character '12434' - lib\pages\emergency_meeting_page.dart:65:23 - illegal_character
  error - Illegal character '25351' - lib\pages\emergency_meeting_page.dart:65:24 - illegal_character
  error - Illegal character '25688' - lib\pages\emergency_meeting_page.dart:65:25 - illegal_character
  error - Illegal character '12377' - lib\pages\emergency_meeting_page.dart:65:26 - illegal_character
  error - Illegal character '12427' - lib\pages\emergency_meeting_page.dart:65:27 - illegal_character
  error - Illegal character '12371' - lib\pages\emergency_meeting_page.dart:65:28 - illegal_character
  error - Illegal character '12392' - lib\pages\emergency_meeting_page.dart:65:29 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:65:30 - illegal_character
  error - Expected to find ';' - lib\pages\emergency_meeting_page.dart:66:3 - expected_token
  error - Illegal character '39348' - lib\pages\emergency_meeting_page.dart:66:3 - illegal_character
  error - Undefined name '馴れ合いは不要。ビジネスライクかつ辛口に。' - lib\pages\emergency_meeting_page.dart:66:3 - undefined_identifier
  error - Illegal character '12428' - lib\pages\emergency_meeting_page.dart:66:4 - illegal_character
  error - Illegal character '21512' - lib\pages\emergency_meeting_page.dart:66:5 - illegal_character
  error - Illegal character '12356' - lib\pages\emergency_meeting_page.dart:66:6 - illegal_character
  error - Illegal character '12399' - lib\pages\emergency_meeting_page.dart:66:7 - illegal_character
  error - Illegal character '19981' - lib\pages\emergency_meeting_page.dart:66:8 - illegal_character
  error - Illegal character '35201' - lib\pages\emergency_meeting_page.dart:66:9 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:66:10 - illegal_character
  error - Illegal character '12499' - lib\pages\emergency_meeting_page.dart:66:11 - illegal_character
  error - Illegal character '12472' - lib\pages\emergency_meeting_page.dart:66:12 - illegal_character
  error - Illegal character '12493' - lib\pages\emergency_meeting_page.dart:66:13 - illegal_character
  error - Illegal character '12473' - lib\pages\emergency_meeting_page.dart:66:14 - illegal_character
  error - Illegal character '12521' - lib\pages\emergency_meeting_page.dart:66:15 - illegal_character
  error - Illegal character '12452' - lib\pages\emergency_meeting_page.dart:66:16 - illegal_character
  error - Illegal character '12463' - lib\pages\emergency_meeting_page.dart:66:17 - illegal_character
  error - Illegal character '12363' - lib\pages\emergency_meeting_page.dart:66:18 - illegal_character
  error - Illegal character '12388' - lib\pages\emergency_meeting_page.dart:66:19 - illegal_character
  error - Illegal character '36763' - lib\pages\emergency_meeting_page.dart:66:20 - illegal_character
  error - Illegal character '21475' - lib\pages\emergency_meeting_page.dart:66:21 - illegal_character
  error - Illegal character '12395' - lib\pages\emergency_meeting_page.dart:66:22 - illegal_character
  error - Illegal character '12290' - lib\pages\emergency_meeting_page.dart:66:23 - illegal_character
   info - Unnecessary use of double quotes - lib\pages\emergency_meeting_page.dart:67:1 - prefer_single_quotes
   info - Method invocation or property access on a 'dynamic' target - lib\pages\emergency_meeting_page.dart:91:25 - avoid_dynamic_calls
   info - Use 'const' with the constructor to improve performance - lib\pages\emergency_meeting_page.dart:96:52 - prefer_const_constructors
   info - Use 'const' with the constructor to improve performance - lib\pages\emergency_meeting_page.dart:96:70 - prefer_const_constructors
   info - Empty catch block - lib\pages\gemini_university_page.dart:53:17 - empty_catches
   info - Method invocation or property access on a 'dynamic' target - lib\pages\gemini_university_page.dart:78:28 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\gemini_university_page.dart:79:26 - avoid_dynamic_calls
   info - Don't use 'BuildContext's across async gaps - lib\pages\gemini_university_page.dart:82:28 - use_build_context_synchronously
   info - Method invocation or property access on a 'dynamic' target - lib\pages\gemini_university_page.dart:108:29 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\gemini_university_page.dart:109:24 - avoid_dynamic_calls
   info - Don't use 'BuildContext's across async gaps - lib\pages\gemini_university_page.dart:112:28 - use_build_context_synchronously
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\gemini_university_page.dart:353:31 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\gemini_university_page.dart:353:37 - deprecated_member_use
   info - Missing a required trailing comma - lib\pages\health_page.dart:122:65 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\health_page.dart:122:66 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\health_page.dart:137:53 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\health_page.dart:141:71 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\health_page.dart:141:72 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:62:70 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:68:60 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:70:69 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:72:60 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:78:75 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:80:61 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:86:61 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:88:60 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:90:62 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:92:68 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:113:74 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:113:75 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:129:72 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:131:72 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:137:67 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:137:68 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:150:32 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:169:49 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:170:74 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:175:72 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:177:58 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\home_page.dart:177:59 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\landing_page.dart:24:66 - require_trailing_commas
   info - Statements in an if should be enclosed in a block - lib\pages\landing_page.dart:34:11 - curly_braces_in_flow_control_structures
   info - Missing a required trailing comma - lib\pages\landing_page.dart:35:66 - require_trailing_commas
   info - Statements in an if should be enclosed in a block - lib\pages\landing_page.dart:40:11 - curly_braces_in_flow_control_structures
   info - Missing a required trailing comma - lib\pages\landing_page.dart:41:75 - require_trailing_commas
   info - Statements in an if should be enclosed in a block - lib\pages\landing_page.dart:45:9 - curly_braces_in_flow_control_structures
   info - Missing a required trailing comma - lib\pages\landing_page.dart:65:78 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\landing_page.dart:67:69 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\landing_page.dart:101:63 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\landing_page.dart:108:77 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\note_editor_page.dart:139:58 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\note_editor_page.dart:166:70 - require_trailing_commas
   info - Don't use 'BuildContext's across async gaps - lib\pages\onboarding_page.dart:68:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\pages\real_world_danshari_page.dart:39:28 - use_build_context_synchronously
   info - Method invocation or property access on a 'dynamic' target - lib\pages\real_world_danshari_page.dart:64:27 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\real_world_danshari_page.dart:66:21 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\pages\real_world_danshari_page.dart:69:25 - avoid_dynamic_calls
   info - Don't use 'BuildContext's across async gaps - lib\pages\real_world_danshari_page.dart:72:28 - use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps - lib\pages\share_note_dialog.dart:20:17 - use_build_context_synchronously
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\share_note_dialog.dart:26:11 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\share_note_dialog.dart:26:17 - deprecated_member_use
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\pages\share_philosopher_quote_dialog.dart:601:13 - deprecated_member_use
   info - 'shareXFiles' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\pages\share_philosopher_quote_dialog.dart:601:19 - deprecated_member_use
  error - The value of the local variable 'themeService' isn't used - lib\pages\stats_page.dart:33:11 - unused_local_variable
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:78:41 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:131:77 - require_trailing_commas
   info - Unnecessary use of string interpolation - lib\pages\subscription_page.dart:133:25 - unnecessary_string_interpolations
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:137:53 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:151:54 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:158:70 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:158:71 - require_trailing_commas
   info - Missing a required trailing comma - lib\pages\subscription_page.dart:161:59 - require_trailing_commas
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\services\app_share_service.dart:375:13 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\services\app_share_service.dart:375:19 - deprecated_member_use
   info - Method invocation or property access on a 'dynamic' target - lib\services\daily_challenge_service.dart:32:31 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\services\daily_challenge_service.dart:33:27 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\services\daily_challenge_service.dart:34:29 - avoid_dynamic_calls
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\services\note_card_service.dart:226:13 - deprecated_member_use
   info - 'shareXFiles' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\services\note_card_service.dart:226:19 - deprecated_member_use
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\services\viral_growth_service.dart:10:11 - deprecated_member_use
   info - 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\services\viral_growth_service.dart:10:17 - deprecated_member_use
   info - Method invocation or property access on a 'dynamic' target - lib\widgets\note_editor\board_meeting_dialog.dart:48:32 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\widgets\note_editor\board_meeting_dialog.dart:49:32 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\widgets\note_editor\board_meeting_dialog.dart:50:32 - avoid_dynamic_calls
   info - Method invocation or property access on a 'dynamic' target - lib\widgets\note_editor\board_meeting_dialog.dart:59:29 - avoid_dynamic_calls
   info - 'Share' is deprecated and shouldn't be used. Use SharePlus instead - lib\widgets\share_note_card_dialog.dart:821:13 - deprecated_member_use
   info - 'shareXFiles' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead - lib\widgets\share_note_card_dialog.dart:821:19 - deprecated_member_use
   info - Missing a required trailing comma - test\models\board_meeting_model_test.dart:37:11 - require_trailing_commas
   info - Missing a required trailing comma - test\models\board_meeting_model_test.dart:39:7 - require_trailing_commas

flutter : 504 issues found. (ran in 67.0s)
発生場所 行:1 文字:19
+ $analysisOutput = flutter analyze 2>&1 | Out-String
+                   ~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (504 issues found. (ran in 67.0s):String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 

```