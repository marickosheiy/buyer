import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // =========================================================
  // LUMEAR COLORS
  // =========================================================

  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),

          child: Column(
            children: [
              // =================================================
              // PAGE TITLE
              // =================================================

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile',
                  style: TextStyle(
                    color: darkMaroon,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =================================================
              // PROFILE PHOTO
              // =================================================

              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: fieldColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: maroon,
                  size: 55,
                ),
              ),

              const SizedBox(height: 15),

              // =================================================
              // USER INFORMATION
              // =================================================

              const Text(
                'Lumear Buyer',
                style: TextStyle(
                  color: darkMaroon,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'buyer@lumear.com',
                style: TextStyle(
                  color: lightMaroon,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // ACCOUNT SECTION
              // =================================================

              buildSectionTitle('Account'),

              const SizedBox(height: 12),

              buildProfileOption(
                icon: Icons.person_outline_rounded,
                title: 'My Account',
                subtitle: 'Manage your personal information',
              ),

              buildProfileOption(
                icon: Icons.location_on_outlined,
                title: 'Addresses',
                subtitle: 'Manage your delivery addresses',
              ),

              buildProfileOption(
                icon: Icons.payment_outlined,
                title: 'Payment Methods',
                subtitle: 'Manage your payment options',
              ),

              const SizedBox(height: 24),

              // =================================================
              // SETTINGS SECTION
              // =================================================

              buildSectionTitle('Settings'),

              const SizedBox(height: 12),

              buildProfileOption(
                icon: Icons.notifications_none_rounded,
                title: 'Notification Settings',
                subtitle: 'Manage your notification preferences',
              ),

              buildProfileOption(
                icon: Icons.settings_outlined,
                title: 'App Settings',
                subtitle: 'Manage your application preferences',
              ),

              const SizedBox(height: 24),

              // =================================================
              // SUPPORT SECTION
              // =================================================

              buildSectionTitle('Support'),

              const SizedBox(height: 12),

              buildProfileOption(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
                subtitle: 'Get help and support',
              ),

              buildProfileOption(
                icon: Icons.info_outline_rounded,
                title: 'About Lumear',
                subtitle: 'Learn more about the application',
              ),

              const SizedBox(height: 24),

              // =================================================
              // LOG OUT BUTTON
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 52,

                child: OutlinedButton.icon(
                  onPressed: () {
                    // We can connect this to the Login page later.
                  },

                  icon: const Icon(
                    Icons.logout_rounded,
                    color: maroon,
                  ),

                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: maroon,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: maroon,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Text(
        title,
        style: const TextStyle(
          color: darkMaroon,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // PROFILE OPTION
  // =========================================================

  Widget buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: const Color(0xFFECDCD4),
        ),
      ),

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),

        leading: Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(13),
          ),

          child: Icon(
            icon,
            color: maroon,
            size: 23,
          ),
        ),

        title: Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),

          child: Text(
            subtitle,
            style: const TextStyle(
              color: lightMaroon,
              fontSize: 11,
            ),
          ),
        ),

        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: lightMaroon,
          size: 16,
        ),


        onTap: () {
          // Individual pages can be added later.
        },
      ),
    );
  }
}