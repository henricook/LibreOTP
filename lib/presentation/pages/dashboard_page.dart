import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../state/otp_state.dart';
import '../widgets/search_bar.dart';
import '../widgets/otp_table.dart';
import '../widgets/notification_toast.dart';
import 'about_page.dart';
import 'data_directory_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  final bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateSearchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchQuery() {
    final otpState = Provider.of<OtpState>(context, listen: false);
    otpState.setSearchQuery(_searchController.text);
  }

  void _showDataDirectory(BuildContext context) {
    final otpState = Provider.of<OtpState>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DataDirectoryPage(dataDirectory: otpState.dataDirectory);
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AboutPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(AppConfig.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: const Text('Show Data Directory'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showDataDirectory(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('About'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showAboutDialog(context);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<OtpState>(
        builder: (context, otpState, child) {
          if (otpState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Column(
                children: [
                  SearchBarWidget(
                    controller: _searchController,
                    onClear: () {
                      _searchController.clear();
                      _updateSearchQuery();
                    },
                    onChanged: (_) => _updateSearchQuery(),
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: OtpTable(
                            groupedServices: otpState.groupedServices,
                            groupNames: otpState.getGroupNames(),
                            onRowTap: (groupId, index) => 
                                otpState.generateOtp(groupId, index, context),
                            sortAscending: _sortAscending,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (otpState.showNotification)
                const NotificationToast(message: 'OTP Code Copied to Clipboard!'),
            ],
          );
        },
      ),
    );
  }
}