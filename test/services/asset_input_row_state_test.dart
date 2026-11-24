import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_input_row_state.dart';

void main() {
  group('resolveAssetInputRowEditState (#4096)', () {
    test('returns unrecorded when not updated today regardless of text', () {
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: false,
          recordedAmount: 10000,
          rawInput: '15000',
        ),
        AssetInputRowEditState.unrecorded,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: false,
          recordedAmount: null,
          rawInput: '',
        ),
        AssetInputRowEditState.unrecorded,
      );
    });

    test('returns savedToday when empty, invalid, or matching recorded amount',
        () {
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: '',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: '   ',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: 'abc',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: '12500',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: ' 12,500 ',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: -50000,
          rawInput: '-50,000',
        ),
        AssetInputRowEditState.savedToday,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 100.0,
          rawInput: '100.004',
        ),
        AssetInputRowEditState.savedToday,
      );
    });

    test(
        'returns dirtyEdit when parsed amount differs or recordedAmount missing',
        () {
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: 12500,
          rawInput: '13000',
        ),
        AssetInputRowEditState.dirtyEdit,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: -50000,
          rawInput: '-45,000',
        ),
        AssetInputRowEditState.dirtyEdit,
      );
      expect(
        resolveAssetInputRowEditState(
          isUpdatedToday: true,
          recordedAmount: null,
          rawInput: '1000',
        ),
        AssetInputRowEditState.dirtyEdit,
      );
    });
  });
}
