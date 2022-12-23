import 'package:process_run/shell.dart';

/// A simple scripts to create production builds for the android and app store from a sinle command
Future<void> main(List<String> args) async {
  // String buildName = '4.2.2';
  // int buildNumber = 132;

  Shell shell = Shell();
  print('\r\n--------------------- CREATING PROD BUILDS ---------------------');
  await shell.run('flutter build ipa --release --export-method app-store');
  await shell.cd('build/ios/ipa/').run('open .');
  print(
      '\r\n--------------------- STARTING ANDROID BUILD ---------------------');
  await shell.run('flutter build appbundle --release');
  await shell.cd('build/app/outputs/bundle/release/').run('open .');
}
