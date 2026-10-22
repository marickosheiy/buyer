import 'design/lumear_theme.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'design/components.dart';
import 'services/api_service.dart';
import 'widgets/email_verification_form.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

const String apiBaseUrl = 'https://psgc.cloud/api/v2';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int currentStep = 0;
  bool isCreatingAccount = false;
  String? verificationToken, verifiedEmail;
  void emailChanged() {
    if (verifiedEmail != null &&
        verifiedEmail != emailController.text.trim().toLowerCase()) {
      setState(() {
        verificationToken = null;
        verifiedEmail = null;
      });
    }
  }

  // The server assigns only the selected buyer/seller role.

  String selectedAccountType = 'Buyer';

  // Seller-only details and private document uploads.
  final shopNameController = TextEditingController();
  final shopDescriptionController = TextEditingController();
  String? governmentIdFileName;
  String? selfieWithIdFileName;
  String? businessDocumentFileName;

  // ============================================================

  // COLORS

  // ============================================================

  static Color get maroon => LumearColors.maroon;

  static Color get darkMaroon => LumearColors.dark;

  static Color get cream => LumearColors.cream;

  static Color get fieldColor => LumearColors.field;

  static Color get borderColor => LumearColors.border;

  static Color get lightText => LumearColors.light;

  // ============================================================

  // CONTROLLERS

  // ============================================================

  final firstNameController = TextEditingController();

  final middleNameController = TextEditingController();

  final lastNameController = TextEditingController();

  final emailController = TextEditingController();

  final phoneController = TextEditingController();

  final passwordController = TextEditingController();

  final confirmPasswordController = TextEditingController();

  final streetController = TextEditingController();

  final houseController = TextEditingController();

  // ============================================================

  // DATE OF BIRTH

  // ============================================================

  DateTime? selectedDateOfBirth;

  // ============================================================

  // PASSWORD

  // ============================================================

  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

  // ============================================================

  // ACCOUNT REGISTRATION

  // ============================================================

  final Map<String, Map<String, String>> sellerDocuments = {};

  // ============================================================

  // VALIDATION

  // ============================================================

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static final _phoneRegex = RegExp(r'^(09\d{9}|\+639\d{9})$');

  static final _passwordRegex = RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$',
  );

  // ============================================================

  // PSGC API

  // ============================================================

  // Use the apiBaseUrl constant declared above the widget class.

  List<Map<String, dynamic>> regions = [];

  List<Map<String, dynamic>> provinces = [];

  List<Map<String, dynamic>> municipalities = [];

  List<Map<String, dynamic>> barangays = [];

  String? selectedRegionCode;

  String? selectedRegionName;

  String? selectedProvinceCode;

  String? selectedProvinceName;

  String? selectedMunicipalityCode;

  String? selectedMunicipalityName;

  String? selectedBarangayCode;

  String? selectedBarangayName;

  bool loadingRegions = false;

  bool loadingProvinces = false;

  bool loadingMunicipalities = false;

  bool loadingBarangays = false;

  // Request "epoch" counters.

  int _regionRequest = 0;

  int _provinceRequest = 0;

  int _municipalityRequest = 0;

  int _barangayRequest = 0;

  // ============================================================

  // INIT / DISPOSE

  // ============================================================

  @override
  void initState() {
    super.initState();
    emailController.addListener(emailChanged);
    loadRegions();
  }

  @override
  void dispose() {
    emailController.removeListener(emailChanged);
    firstNameController.dispose();

    middleNameController.dispose();

    lastNameController.dispose();

    emailController.dispose();

    phoneController.dispose();

    passwordController.dispose();

    confirmPasswordController.dispose();

    streetController.dispose();

    houseController.dispose();

    super.dispose();
  }

  // ============================================================

  // AGE RESTRICTION

  // ============================================================

  int calculateAge(DateTime birthDate) {
    final today = DateTime.now();

    int age = today.year - birthDate.year;

    final hasHadBirthdayThisYear =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);

    if (!hasHadBirthdayThisYear) {
      age--;
    }

    return age;
  }

  DateTime get maximumBirthDateFor18 {
    final today = DateTime.now();

    return DateTime(today.year - 18, today.month, today.day);
  }

  Future<void> selectDateOfBirth() async {
    final today = DateTime.now();

    final maximumBirthDate = maximumBirthDateFor18;

    DateTime initialDate = selectedDateOfBirth ?? maximumBirthDate;

    if (initialDate.isAfter(maximumBirthDate)) {
      initialDate = maximumBirthDate;
    }

    final selected = await showDatePicker(
      context: context,

      initialDate: initialDate,

      firstDate: DateTime(1900),

      lastDate: maximumBirthDate,

      currentDate: today,

      initialDatePickerMode: DatePickerMode.year,

      helpText: 'SELECT YOUR DATE OF BIRTH',

      cancelText: 'CANCEL',

      confirmText: 'CONFIRM',

      errorFormatText: 'Enter a valid date.',

      errorInvalidText: 'You must be 18 years old or above.',
    );

    if (selected == null) {
      return;
    }

    final age = calculateAge(selected);

    if (age < 18) {
      showAgeRestrictionDialog();

      return;
    }

    setState(() {
      selectedDateOfBirth = selected;
    });
  }

  void showAgeRestrictionDialog() {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          backgroundColor: cream,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          icon: Icon(Icons.lock_outline_rounded, color: maroon, size: 52),

          title: Text(
            'Age Restriction',

            textAlign: TextAlign.center,

            style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
          ),

          content: Text(
            'You must be 18 years old or above to create a Lumear account.',

            textAlign: TextAlign.center,

            style: TextStyle(color: LumearColors.ink, height: 1.5),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: LumearColors.action,

                foregroundColor: LumearColors.ivory,

                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================

  // API GET LIST

  // ============================================================

  Future<List<Map<String, dynamic>>> getList(String url) async {
    debugPrint('GET: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    );

    debugPrint('STATUS: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];

      if (data is List) {
        return data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    }

    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw Exception('Unexpected API response format.');
  }

  // ============================================================

  // LOAD REGIONS

  // ============================================================

  Future<void> loadRegions() async {
    final requestId = ++_regionRequest;

    setState(() {
      loadingRegions = true;
    });

    try {
      final result = await getList('$apiBaseUrl/regions');

      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _regionRequest) {
        return;
      }

      setState(() {
        regions = result;

        loadingRegions = false;
      });
    } catch (e) {
      debugPrint('REGION ERROR: $e');

      if (!mounted || requestId != _regionRequest) {
        return;
      }

      setState(() {
        loadingRegions = false;
      });

      showMessage(
        'Unable to load regions.',

        actionLabel: 'RETRY',

        onAction: loadRegions,
      );
    }
  }

  // ============================================================
  // LOAD PROVINCES
  // ============================================================

  Future<void> loadProvinces(String regionCode) async {
    final requestId = ++_provinceRequest;

    setState(() {
      loadingProvinces = true;
      provinces = [];
      municipalities = [];
      barangays = [];
      selectedProvinceCode = null;
      selectedProvinceName = null;
      selectedMunicipalityCode = null;
      selectedMunicipalityName = null;
      selectedBarangayCode = null;
      selectedBarangayName = null;
    });

    try {
      final result = await getList('$apiBaseUrl/regions/$regionCode/provinces');

      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _provinceRequest) return;

      setState(() {
        provinces = result;
        loadingProvinces = false;
      });
    } catch (e) {
      debugPrint('PROVINCE ERROR: $e');
      if (!mounted || requestId != _provinceRequest) return;

      setState(() {
        loadingProvinces = false;
      });
      showMessage(
        'Unable to load provinces.',
        actionLabel: 'RETRY',
        onAction: () => loadProvinces(regionCode),
      );
    }
  }

  // ============================================================

  // LOAD CITIES / MUNICIPALITIES

  // ============================================================

  Future<void> loadMunicipalities(String provinceCode) async {
    final requestId = ++_municipalityRequest;

    setState(() {
      loadingMunicipalities = true;

      municipalities = [];

      barangays = [];

      selectedMunicipalityCode = null;

      selectedMunicipalityName = null;

      selectedBarangayCode = null;

      selectedBarangayName = null;
    });

    try {
      final result = await getList(
        '$apiBaseUrl/provinces/'
        '$provinceCode/cities-municipalities',
      );

      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _municipalityRequest) {
        return;
      }

      setState(() {
        municipalities = result;

        loadingMunicipalities = false;
      });
    } catch (e) {
      debugPrint('MUNICIPALITY ERROR: $e');

      if (!mounted || requestId != _municipalityRequest) {
        return;
      }

      setState(() {
        loadingMunicipalities = false;
      });

      showMessage(
        'Unable to load cities / municipalities.',

        actionLabel: 'RETRY',

        onAction: () => loadMunicipalities(provinceCode),
      );
    }
  }

  // ============================================================

  // LOAD BARANGAYS

  // ============================================================

  Future<void> loadBarangays(String municipalityCode) async {
    final requestId = ++_barangayRequest;

    setState(() {
      loadingBarangays = true;

      barangays = [];

      selectedBarangayCode = null;

      selectedBarangayName = null;
    });

    try {
      final result = await getList(
        '$apiBaseUrl/cities-municipalities/'
        '$municipalityCode/barangays',
      );

      result.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (!mounted || requestId != _barangayRequest) {
        return;
      }

      setState(() {
        barangays = result;

        loadingBarangays = false;
      });
    } catch (e) {
      debugPrint('BARANGAY ERROR: $e');

      if (!mounted || requestId != _barangayRequest) {
        return;
      }

      setState(() {
        loadingBarangays = false;
      });

      showMessage(
        'Unable to load barangays.',

        actionLabel: 'RETRY',

        onAction: () => loadBarangays(municipalityCode),
      );
    }
  }

  // ============================================================

  // MESSAGE

  // ============================================================

  void showMessage(
    String message, {

    String? actionLabel,

    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,

        backgroundColor: LumearColors.action,

        content: Text(message),

        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,

                textColor: Colors.white,

                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  // ============================================================

  // INPUT DESIGN

  // ============================================================

  InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,

      hintStyle: TextStyle(color: lightText, fontSize: 14),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: fieldColor,

      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: maroon, width: 1.5),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: borderColor.withValues(alpha: 0.55)),
      ),
    );
  }

  // ============================================================

  // NEXT / BACK

  // ============================================================

  void nextStep() {
    // ==========================================================

    // STEP 1 - PERSONAL INFORMATION

    // ==========================================================

    if (currentStep == 0) {
      final first = firstNameController.text.trim();

      final last = lastNameController.text.trim();

      final email = emailController.text.trim();

      final phone = phoneController.text.trim();

      final password = passwordController.text;

      final confirm = confirmPasswordController.text;

      if (first.isEmpty ||
          last.isEmpty ||
          email.isEmpty ||
          phone.isEmpty ||
          password.isEmpty ||
          confirm.isEmpty) {
        showMessage('Please complete all required fields.');

        return;
      }

      // AGE RESTRICTION

      if (selectedDateOfBirth == null) {
        showMessage('Please select your date of birth.');

        return;
      }

      final age = calculateAge(selectedDateOfBirth!);

      if (age < 18) {
        showAgeRestrictionDialog();

        return;
      }

      if (!_emailRegex.hasMatch(email)) {
        showMessage('Please enter a valid email address.');

        return;
      }

      if (!_phoneRegex.hasMatch(phone)) {
        showMessage('Please enter a valid PH mobile number.');

        return;
      }

      if (!_passwordRegex.hasMatch(password)) {
        showMessage(
          'Password must be at least 8 characters with uppercase, lowercase and a number.',
        );

        return;
      }

      if (password != confirm) {
        showMessage('Passwords do not match.');

        return;
      }
    }

    // ==========================================================

    // STEP 2 - ADDRESS

    // ==========================================================

    if (currentStep == 1) {
      if (selectedRegionCode == null ||
          selectedProvinceCode == null ||
          selectedMunicipalityCode == null ||
          selectedBarangayCode == null ||
          streetController.text.trim().isEmpty) {
        showMessage('Please complete your address.');

        return;
      }
    }

    // ==========================================================

    // MOVE TO NEXT STEP

    // ==========================================================

    if (currentStep < 2) {
      setState(() {
        currentStep++;
      });
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  // ============================================================

  // ACCOUNT REGISTRATION

  // ============================================================

  Future<void> createAccount() async {
    if (isCreatingAccount) return;
    if (selectedAccountType == 'Seller') {
      if (shopNameController.text.trim().isEmpty ||
          shopDescriptionController.text.trim().isEmpty) {
        showMessage('Please complete your shop name and description.');
        return;
      }
      if (governmentIdFileName == null ||
          selfieWithIdFileName == null ||
          businessDocumentFileName == null) {
        showMessage('Please select all required seller documents.');
        return;
      }
    }

    if (verificationToken == null ||
        verifiedEmail != emailController.text.trim().toLowerCase()) {
      showMessage('Verify your email before creating your account.');
      return;
    }

    // Final age check before account creation.

    //

    // This is intentionally checked again so the

    // restriction exists immediately before the

    // account is considered created.

    if (selectedDateOfBirth == null) {
      showMessage('Please select your date of birth.');

      return;
    }

    final age = calculateAge(selectedDateOfBirth!);

    if (age < 18) {
      showAgeRestrictionDialog();

      return;
    }

    {
      setState(() => isCreatingAccount = true);
      try {
        await ApiService.post(
          '/auth/register',
          body: {
            'name': [
              firstNameController.text.trim(),
              middleNameController.text.trim(),
              lastNameController.text.trim(),
            ].where((s) => s.isNotEmpty).join(' '),
            'email': emailController.text.trim(),
            'verification_token': verificationToken,
            'account_type': selectedAccountType.toLowerCase(),
            if (selectedAccountType == 'Seller') ...{
              'shop_name': shopNameController.text.trim(),
              'shop_description': shopDescriptionController.text.trim(),
              'documents': sellerDocuments,
            },
            'phone': phoneController.text.trim(),
            'password': passwordController.text,
            'date_of_birth': selectedDateOfBirth!
                .toIso8601String()
                .split('T')
                .first,
          },
        );
      } catch (error) {
        if (mounted) showMessage(error.toString());
        return;
      } finally {
        if (mounted) setState(() => isCreatingAccount = false);
      }
      if (!mounted) return;
    }

    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          backgroundColor: cream,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          icon: Icon(
            Icons.check_circle_outline_rounded,

            color: maroon,

            size: 55,
          ),

          title: Text(
            '$selectedAccountType Registration Complete!',

            textAlign: TextAlign.center,

            style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
          ),

          content: Text(
            selectedAccountType == 'Buyer'
                ? 'Your buyer account is saved. Sign in with your email and password. Add a delivery address in your account before checking out.'
                : 'Your seller account is ready. Sign in to add products and start selling.',

            textAlign: TextAlign.center,
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.pop(context);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: LumearColors.action,

                foregroundColor: LumearColors.ivory,
              ),

              child: const Text('GO TO LOGIN'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return Scaffold(
      backgroundColor: cream,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(34, 32, 34, 20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const PageHeading(
                      'A lovely place to start.',
                      eyebrow: 'CREATE YOUR LUMEAR ACCOUNT',
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          'Already registered? ',

                          style: TextStyle(color: lightText, fontSize: 13),
                        ),

                        GestureDetector(
                          onTap: () => Navigator.pop(context),

                          child: Text(
                            'Log in',

                            style: TextStyle(
                              color: darkMaroon,

                              fontWeight: FontWeight.bold,

                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    buildStepper(),

                    const SizedBox(height: 32),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),

                      child: buildCurrentStep(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              color: cream,

              padding: const EdgeInsets.fromLTRB(34, 12, 34, 22),

              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,

                      child: OutlinedButton(
                        onPressed: previousStep,

                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkMaroon,

                          side: BorderSide(color: borderColor),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),

                        child: const Text(
                          'BACK',

                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 50,

                      child: ElevatedButton(
                        onPressed: isCreatingAccount
                            ? null
                            : currentStep == 2
                            ? createAccount
                            : nextStep,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: LumearColors.action,

                          foregroundColor: LumearColors.ivory,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),

                        child: Text(
                          isCreatingAccount
                              ? 'SAVING…'
                              : currentStep == 2
                              ? 'CREATE ACCOUNT'
                              : 'CONTINUE',

                          style: const TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // STEPPER

  // ============================================================

  Widget buildStepper() {
    return Row(
      children: [
        buildStep(index: 0, label: 'Personal'),

        buildLine(0),

        buildStep(index: 1, label: 'Address'),

        buildLine(1),

        buildStep(index: 2, label: 'Verify'),
      ],
    );
  }

  Widget buildStep({required int index, required String label}) {
    final completed = currentStep > index;

    final active = currentStep == index;

    return Column(
      children: [
        Container(
          width: 34,

          height: 34,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: completed || active
                ? LumearColors.action
                : LumearColors.field,
          ),

          child: Center(
            child: completed
                ? const Icon(Icons.check, size: 18, color: LumearColors.ivory)
                : Text(
                    '${index + 1}',

                    style: TextStyle(
                      color: active ? Colors.white : lightText,

                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          label,

          style: TextStyle(
            fontSize: 10,

            color: completed || active ? LumearColors.action : lightText,
          ),
        ),
      ],
    );
  }

  Widget buildLine(int index) {
    final completed = currentStep > index;

    return Expanded(
      child: Container(
        height: 2,

        margin: const EdgeInsets.only(left: 9, right: 9, bottom: 20),

        color: completed ? maroon : borderColor,
      ),
    );
  }

  // ============================================================

  // CURRENT STEP

  // ============================================================

  Widget buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return buildPersonal();

      case 1:
        return buildAddress();

      case 2:
        return buildVerification();

      default:
        return const SizedBox();
    }
  }

  // ============================================================

  // PERSONAL

  // ============================================================

  Widget _accountTypeCard({
    required String title,

    required String subtitle,

    required IconData icon,
  }) {
    final selected = selectedAccountType == title;

    return InkWell(
      borderRadius: BorderRadius.circular(14),

      onTap: () => setState(() => selectedAccountType = title),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

        decoration: BoxDecoration(
          color: selected ? LumearColors.field : LumearColors.surface,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: selected ? maroon : borderColor,

            width: selected ? 1.6 : 1,
          ),
        ),

        child: Row(
          children: [
            Icon(icon, color: selected ? maroon : lightText, size: 25),

            const SizedBox(width: 9),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: TextStyle(
                      color: darkMaroon,

                      fontWeight: FontWeight.bold,

                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,

                    style: TextStyle(color: lightText, fontSize: 10),
                  ),
                ],
              ),
            ),

            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,

              color: selected ? maroon : lightText,

              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPersonal() {
    return Column(
      key: const ValueKey('personal'),

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Personal information',

          style: TextStyle(
            color: darkMaroon,

            fontWeight: FontWeight.w600,

            fontSize: 18,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'I want to join Lumear as a',

          style: TextStyle(
            color: darkMaroon,

            fontSize: 14,

            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _accountTypeCard(
                title: 'Buyer',

                subtitle: 'Shop for products',

                icon: Icons.shopping_bag_outlined,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _accountTypeCard(
                title: 'Seller',

                subtitle: 'Sell your products',

                icon: Icons.storefront_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // FIRST NAME
        TextField(
          controller: firstNameController,

          decoration: inputDecoration('First name'),
        ),

        const SizedBox(height: 14),

        // MIDDLE NAME
        TextField(
          controller: middleNameController,

          decoration: inputDecoration('Middle name'),
        ),

        const SizedBox(height: 14),

        // LAST NAME
        TextField(
          controller: lastNameController,

          decoration: inputDecoration('Last name'),
        ),

        const SizedBox(height: 14),

        // EMAIL
        TextField(
          controller: emailController,

          keyboardType: TextInputType.emailAddress,

          decoration: inputDecoration('Email address'),
        ),

        const SizedBox(height: 14),

        // PHONE
        TextField(
          controller: phoneController,

          keyboardType: TextInputType.phone,

          decoration: inputDecoration('Mobile number'),
        ),

        const SizedBox(height: 14),

        // ======================================================

        // DATE OF BIRTH

        // ======================================================
        InkWell(
          onTap: selectDateOfBirth,

          borderRadius: BorderRadius.circular(13),

          child: InputDecorator(
            decoration: inputDecoration(
              'Date of birth *',

              suffixIcon: Icon(Icons.calendar_today_outlined, color: lightText),
            ),

            child: Text(
              selectedDateOfBirth == null
                  ? 'Select your date of birth'
                  : '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
                        '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
                        '${selectedDateOfBirth!.year}',

              style: TextStyle(
                color: selectedDateOfBirth == null
                    ? lightText
                    : LumearColors.ink,

                fontSize: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'You must be 18 years old or above to create a Lumear account.',

          style: TextStyle(color: lightText, fontSize: 11, height: 1.4),
        ),

        const SizedBox(height: 14),

        // PASSWORD
        TextField(
          controller: passwordController,

          obscureText: obscurePassword,

          decoration: inputDecoration(
            'Password*',

            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },

              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color: lightText,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // CONFIRM PASSWORD
        TextField(
          controller: confirmPasswordController,

          obscureText: obscureConfirmPassword,

          decoration: inputDecoration(
            'Confirm password*',

            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscureConfirmPassword = !obscureConfirmPassword;
                });
              },

              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color: lightText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================

  // ADDRESS

  // ============================================================

  Widget buildAddress() {
    return Column(
      key: const ValueKey('address'),

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        if (regions.isEmpty && !loadingRegions)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),

            child: InkWell(
              borderRadius: BorderRadius.circular(13),

              onTap: loadRegions,

              child: Container(
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: fieldColor,

                  borderRadius: BorderRadius.circular(13),

                  border: Border.all(color: borderColor),
                ),

                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: maroon, size: 20),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        "Couldn't load regions. Tap to retry.",

                        style: TextStyle(color: darkMaroon, fontSize: 13),
                      ),
                    ),

                    Icon(Icons.refresh_rounded, color: maroon, size: 18),
                  ],
                ),
              ),
            ),
          ),

        // REGION
        _SearchableField(
          hint: 'Region*',

          selectedLabel: selectedRegionName,

          items: regions,

          itemLabel: (item) => item['name'].toString(),

          enabled: true,

          loading: loadingRegions,

          decoration: inputDecoration,

          onSelected: (item) {
            final code = item['code'].toString();

            setState(() {
              selectedRegionCode = code;

              selectedRegionName = item['name'].toString();
            });

            loadProvinces(code);
          },
        ),

        const SizedBox(height: 14),

        // PROVINCE
        _SearchableField(
          hint: 'Province*',

          selectedLabel: selectedProvinceName,

          items: provinces,

          itemLabel: (item) => item['name'].toString(),

          enabled: selectedRegionCode != null,

          loading: loadingProvinces,

          decoration: inputDecoration,

          onSelected: (item) {
            final code = item['code'].toString();

            setState(() {
              selectedProvinceCode = code;

              selectedProvinceName = item['name'].toString();
            });

            loadMunicipalities(code);
          },
        ),

        const SizedBox(height: 14),

        // CITY / MUNICIPALITY
        _SearchableField(
          hint: 'City / Municipality*',

          selectedLabel: selectedMunicipalityName,

          items: municipalities,

          itemLabel: (item) => item['name'].toString(),

          enabled: selectedProvinceCode != null,

          loading: loadingMunicipalities,

          decoration: inputDecoration,

          onSelected: (item) {
            final code = item['code'].toString();

            setState(() {
              selectedMunicipalityCode = code;

              selectedMunicipalityName = item['name'].toString();
            });

            loadBarangays(code);
          },
        ),

        const SizedBox(height: 14),

        // BARANGAY
        _SearchableField(
          hint: 'Barangay*',

          selectedLabel: selectedBarangayName,

          items: barangays,

          itemLabel: (item) => item['name'].toString(),

          enabled: selectedMunicipalityCode != null,

          loading: loadingBarangays,

          decoration: inputDecoration,

          onSelected: (item) {
            setState(() {
              selectedBarangayCode = item['code'].toString();

              selectedBarangayName = item['name'].toString();
            });
          },
        ),

        const SizedBox(height: 14),

        // STREET
        TextField(
          controller: streetController,

          decoration: inputDecoration('Street*'),
        ),

        const SizedBox(height: 14),

        // HOUSE / UNIT
        TextField(
          controller: houseController,

          decoration: inputDecoration('House / unit no.'),
        ),

        const SizedBox(height: 12),

        Text(
          'Region, province, city/municipality, and barangay are loaded automatically from the Philippine location API. Tap a field to search.',

          style: TextStyle(color: lightText, fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  // ============================================================

  // VERIFY

  // ============================================================

  Future<void> pickSellerDocument(String documentType) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (files.isEmpty || !mounted) {
        return;
      }

      final fileName = files.first.name;
      final bytes = await files.first.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        showMessage('Select a document of at most 5 MB.');
        return;
      }
      sellerDocuments[documentType] = {
        'name': fileName,
        'data': base64Encode(bytes),
      };

      setState(() {
        switch (documentType) {
          case 'id':
            governmentIdFileName = fileName;
            break;
          case 'selfie':
            selfieWithIdFileName = fileName;
            break;
          case 'business':
            businessDocumentFileName = fileName;
            break;
        }
      });

      showMessage('Selected: $fileName');
    } catch (e) {
      debugPrint('Seller document picker error: $e');
      showMessage('Unable to select the file. Please try again.');
    }
  }

  Widget sellerDocumentField({
    required String title,
    required String description,
    required String documentType,
    required String? fileName,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file_rounded, color: maroon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: darkMaroon,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (fileName != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(color: lightText, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (fileName != null) ...[
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: darkMaroon, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => pickSellerDocument(documentType),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(fileName == null ? 'SELECT FILE' : 'CHANGE FILE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: maroon,
              side: BorderSide(color: borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSellerRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Divider(color: borderColor),
        const SizedBox(height: 16),
        Text(
          'Seller information',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete your shop details and select the required documents. Accepted files: JPG, PNG, or PDF.',
          style: TextStyle(color: lightText, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: shopNameController,
          decoration: inputDecoration('Shop name *').copyWith(
            prefixIcon: Icon(Icons.storefront_outlined, color: lightText),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: shopDescriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: inputDecoration('Shop description *').copyWith(
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 35),
              child: Icon(Icons.description_outlined, color: lightText),
            ),
          ),
        ),
        const SizedBox(height: 16),
        sellerDocumentField(
          title: 'Government-issued ID *',
          description:
              'Select a clear image or PDF of your valid government-issued ID.',
          documentType: 'id',
          fileName: governmentIdFileName,
        ),
        sellerDocumentField(
          title: 'Selfie with ID *',
          description: 'Select a clear selfie showing you holding your ID.',
          documentType: 'selfie',
          fileName: selfieWithIdFileName,
        ),
        sellerDocumentField(
          title: 'Business registration document *',
          description: 'Required for seller verification. Select your business registration document as an image or PDF.',
          documentType: 'business',
          fileName: businessDocumentFileName,
        ),
        Text(
          'Your documents are uploaded privately for seller approval when you create the account.',
          style: TextStyle(color: lightText, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget buildVerification() => Column(
    key: const ValueKey('verify'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Verify your account',
        style: TextStyle(
          color: darkMaroon,
          fontWeight: FontWeight.w600,
          fontSize: 19,
        ),
      ),
      const SizedBox(height: 16),
      EmailVerificationForm(
        key: ValueKey(emailController.text.trim().toLowerCase()),
        email: emailController.text.trim().toLowerCase(),
        onVerified: (proof) {
          setState(() {
            verificationToken = proof;
            verifiedEmail = emailController.text.trim().toLowerCase();
          });
        },
      ),
      const SizedBox(height: 20),
      if (selectedAccountType == 'Seller') buildSellerRequirements(),
    ],
  );
}

// ============================================================

// SEARCHABLE PICKER FIELD

// ============================================================

class _SearchableField extends StatelessWidget {
  const _SearchableField({
    required this.hint,

    required this.selectedLabel,

    required this.items,

    required this.itemLabel,

    required this.enabled,

    required this.loading,

    required this.onSelected,

    required this.decoration,
  });

  final String hint;

  final String? selectedLabel;

  final List<Map<String, dynamic>> items;

  final String Function(Map<String, dynamic>) itemLabel;

  final bool enabled;

  final bool loading;

  final ValueChanged<Map<String, dynamic>> onSelected;

  final InputDecoration Function(String, {Widget? suffixIcon}) decoration;

  bool get _canTap => enabled && !loading && items.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return InkWell(
      borderRadius: BorderRadius.circular(13),

      onTap: _canTap ? () => _openPicker(context) : null,

      child: InputDecorator(
        decoration: decoration(
          loading ? '$hint (loading...)' : hint,

          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),

                  child: SizedBox(
                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  Icons.keyboard_arrow_down_rounded,

                  color: _canTap
                      ? _RegisterPageState.darkMaroon
                      : _RegisterPageState.lightText,
                ),
        ),

        child: Text(
          selectedLabel ?? '',

          overflow: TextOverflow.ellipsis,

          style: TextStyle(
            color: selectedLabel == null
                ? _RegisterPageState.lightText
                : LumearColors.ink,

            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) =>
          _PickerSheet(title: hint, items: items, itemLabel: itemLabel),
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

// ============================================================

// PICKER SHEET

// ============================================================

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,

    required this.items,

    required this.itemLabel,
  });

  final String title;

  final List<Map<String, dynamic>> items;

  final String Function(Map<String, dynamic>) itemLabel;

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.65,

      minChildSize: 0.35,

      maxChildSize: 0.92,

      expand: false,

      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _RegisterPageState.cream,

            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),

          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 40,

                height: 4,

                decoration: BoxDecoration(
                  color: _RegisterPageState.borderColor,

                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),

                child: Align(
                  alignment: Alignment.centerLeft,

                  child: Text(
                    title.replaceAll('*', ''),

                    style: TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w600,

                      color: _RegisterPageState.darkMaroon,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,

                  padding: const EdgeInsets.symmetric(vertical: 6),

                  itemCount: items.length,

                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: _RegisterPageState.borderColor),

                  itemBuilder: (context, index) {
                    final item = items[index];

                    return ListTile(
                      title: Text(itemLabel(item)),

                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
