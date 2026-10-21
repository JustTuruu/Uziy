import 'package:flutter/material.dart';

import '../../services/api_error.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import '../auth/auth_widgets.dart';

const String kAddNameTitle = 'Нэрээ нэмэх';
const String kAddNameNote =
    'Карт дээр болон мөнгө татахад таны овог, нэрийг ашиглана. Нэг л удаа '
    'оруулах тул дансныхаа эзэмшигчийн нэртэй адил бичнэ үү.';
const String kAddNameSave = 'Хадгалах';
const String kAddNameSaved = 'Нэр хадгалагдлаа';

/// Saves the name; throws [ApiException] with a message to show.
typedef SaveName = Future<void> Function(String lastName, String firstName);

/// Opens [AddNameSheet]; true once the name was saved.
Future<bool?> showAddNameSheet(BuildContext context,
    {required SaveName onSave}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AddNameSheet(onSave: onSave),
  );
}

/// For an account made before registration asked for a name: овог + нэр,
/// checked like at registration, saved once.
class AddNameSheet extends StatefulWidget {
  const AddNameSheet({super.key, required this.onSave});

  final SaveName onSave;

  @override
  State<AddNameSheet> createState() => _AddNameSheetState();
}

class _AddNameSheetState extends State<AddNameSheet> {
  final _formKey = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_lastName.text.trim(), _firstName.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = kUnexpectedError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      // Keeps the fields above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.screenPadding,
          0,
          AppLayout.screenPadding,
          AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(kAddNameTitle, style: context.textStyles.title),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                kAddNameNote,
                style: context.textStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              PersonNameFields(
                lastName: _lastName,
                firstName: _firstName,
                onDone: _save,
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                StatusBanner(message: error),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: kAddNameSave,
                loading: _saving,
                haptic: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
