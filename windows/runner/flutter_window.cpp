#include "flutter_window.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Provide basic native window/screen info to the Dart side (used to recover
  // from off-screen window positions after monitor layout changes).
  {
    static constexpr char kChannelName[] = "com.deepnode.altyaziceviri/window";
    static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
    channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        flutter_controller_->engine()->messenger(), kChannelName,
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "getVirtualScreenBounds") {
            const int left = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
            const int top = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
            const int width = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
            const int height = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
            flutter::EncodableMap map;
            map[flutter::EncodableValue("left")] = flutter::EncodableValue(left);
            map[flutter::EncodableValue("top")] = flutter::EncodableValue(top);
            map[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
            map[flutter::EncodableValue("height")] = flutter::EncodableValue(height);
            map[flutter::EncodableValue("right")] = flutter::EncodableValue(left + width);
            map[flutter::EncodableValue("bottom")] = flutter::EncodableValue(top + height);
            result->Success(flutter::EncodableValue(map));
            return;
          }
          result->NotImplemented();
        });
  }

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
