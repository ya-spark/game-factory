// Picks the platform part of the services at compile time. On Android (the product) the vendor
// SDKs are wired; in the web build (a test copy on the Hostinger VPS) none of them is imported
// and the platform-only services are honest stubs. Only `services.dart` imports this file.
export 'platform_services_native.dart'
    if (dart.library.js_interop) 'platform_services_web.dart';
