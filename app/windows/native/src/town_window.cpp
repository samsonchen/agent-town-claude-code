#include "town_window.h"

#include <godot_cpp/core/class_db.hpp>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>

using namespace godot;

namespace {

constexpr UINT_PTR SUBCLASS_ID = 0x70776E; // "twn"

// The office window is kept off the taskbar by being owned by a hidden window: Windows gives an
// owned window no taskbar button. (Until Windows app 1.0.12 it had the tool-window style instead,
// whose title bar has only a close button, so the window could not be maximized.)
LONG_PTR owned_ex_style(LONG_PTR ex) {
	return ex & ~static_cast<LONG_PTR>(WS_EX_APPWINDOW | WS_EX_TOOLWINDOW);
}

// No minimize button: a minimized window with no taskbar button would be hard to find again (the
// tray icon brings the window back, and closing it hides it).
LONG_PTR owned_style(LONG_PTR style) {
	return style & ~static_cast<LONG_PTR>(WS_MINIMIZEBOX);
}

// The hidden owner, made once.
HWND hidden_owner() {
	static HWND owner = nullptr;
	if (owner == nullptr || !IsWindow(owner)) {
		owner = CreateWindowExW(0, L"STATIC", L"agent-town owner", WS_POPUP, 0, 0, 0, 0, nullptr, nullptr,
				GetModuleHandleW(nullptr), nullptr);
	}
	return owner;
}

// Godot rebuilds the window's styles when its own flags change (always on top, borderless …),
// which could bring the taskbar button or the minimize button back. This keeps them out in every
// such change, and turns a minimize (Win+Down) into nothing.
LRESULT CALLBACK keep_off_taskbar(HWND h, UINT msg, WPARAM wp, LPARAM lp, UINT_PTR id, DWORD_PTR) {
	if (msg == WM_STYLECHANGING && wp == static_cast<WPARAM>(GWL_EXSTYLE)) {
		STYLESTRUCT *s = reinterpret_cast<STYLESTRUCT *>(lp);
		s->styleNew = static_cast<DWORD>(owned_ex_style(s->styleNew));
	} else if (msg == WM_STYLECHANGING && wp == static_cast<WPARAM>(GWL_STYLE)) {
		STYLESTRUCT *s = reinterpret_cast<STYLESTRUCT *>(lp);
		s->styleNew = static_cast<DWORD>(owned_style(s->styleNew));
	} else if (msg == WM_SYSCOMMAND && (wp & 0xFFF0) == SC_MINIMIZE) {
		return 0;
	} else if (msg == WM_NCDESTROY) {
		RemoveWindowSubclass(h, keep_off_taskbar, id);
	}
	return DefSubclassProc(h, msg, wp, lp);
}

} // namespace

void TownWindow::_bind_methods() {
	ClassDB::bind_static_method("TownWindow", D_METHOD("hide_from_taskbar", "hwnd"), &TownWindow::hide_from_taskbar);
	ClassDB::bind_static_method("TownWindow", D_METHOD("is_hidden_from_taskbar", "hwnd"), &TownWindow::is_hidden_from_taskbar);
	ClassDB::bind_static_method("TownWindow", D_METHOD("set_shown", "hwnd", "shown"), &TownWindow::set_shown);
	ClassDB::bind_static_method("TownWindow", D_METHOD("is_shown", "hwnd"), &TownWindow::is_shown);
	ClassDB::bind_static_method("TownWindow", D_METHOD("show_without_focus", "hwnd"), &TownWindow::show_without_focus);
	ClassDB::bind_static_method("TownWindow", D_METHOD("set_owner", "hwnd", "owner_hwnd"), &TownWindow::set_owner);
	ClassDB::bind_static_method("TownWindow", D_METHOD("get_owner", "hwnd"), &TownWindow::get_owner);
}

// Windows gives no taskbar button to an owned window. The change only takes effect on the taskbar
// when the window is shown again, so a visible window is hidden and shown around it.
bool TownWindow::hide_from_taskbar(int64_t hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	HWND owner = hidden_owner();
	if (!IsWindow(h) || owner == nullptr) {
		return false;
	}
	SetWindowSubclass(h, keep_off_taskbar, SUBCLASS_ID, 0); // a second call only updates it
	LONG_PTR ex = GetWindowLongPtrW(h, GWL_EXSTYLE);
	LONG_PTR style = GetWindowLongPtrW(h, GWL_STYLE);
	if (GetWindow(h, GW_OWNER) == owner && owned_ex_style(ex) == ex && owned_style(style) == style) {
		return true;
	}
	bool visible = IsWindowVisible(h) != FALSE;
	if (visible) {
		ShowWindow(h, SW_HIDE);
	}
	SetWindowLongPtrW(h, GWLP_HWNDPARENT, reinterpret_cast<LONG_PTR>(owner));
	SetWindowLongPtrW(h, GWL_EXSTYLE, owned_ex_style(ex));
	SetWindowLongPtrW(h, GWL_STYLE, owned_style(style));
	SetWindowPos(h, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
	if (visible) {
		ShowWindow(h, SW_SHOWNA);
	}
	return true;
}

// No taskbar button: owned and without WS_EX_APPWINDOW, or a tool window.
bool TownWindow::is_hidden_from_taskbar(int64_t hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	if (!IsWindow(h)) {
		return false;
	}
	LONG_PTR ex = GetWindowLongPtrW(h, GWL_EXSTYLE);
	return (ex & WS_EX_TOOLWINDOW) != 0 || (GetWindow(h, GW_OWNER) != nullptr && (ex & WS_EX_APPWINDOW) == 0);
}

// Godot cannot hide its main window; this hides or shows it the Windows way.
void TownWindow::set_shown(int64_t hwnd, bool shown) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	if (!IsWindow(h)) {
		return;
	}
	if (shown) {
		ShowWindow(h, IsIconic(h) ? SW_RESTORE : SW_SHOW);
		SetForegroundWindow(h);
	} else {
		ShowWindow(h, SW_HIDE);
	}
}

bool TownWindow::is_shown(int64_t hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	return IsWindow(h) && IsWindowVisible(h) != FALSE;
}

// Shows a hidden window where it was, without activating it, so whatever the user is typing in
// keeps the focus (the office coming back when a session opens).
void TownWindow::show_without_focus(int64_t hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	if (IsWindow(h)) {
		ShowWindow(h, SW_SHOWNA);
	}
}

// Makes `owner_hwnd` the owner of `hwnd`: Windows then keeps the window above its owner, also when
// the owner is always on top and is clicked (Godot's transient windows get no owner). An owned
// window has no taskbar button of its own. 0 removes the owner.
bool TownWindow::set_owner(int64_t hwnd, int64_t owner_hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	HWND owner = reinterpret_cast<HWND>(owner_hwnd);
	if (!IsWindow(h) || (owner != nullptr && !IsWindow(owner)) || owner == h) {
		return false;
	}
	SetWindowLongPtrW(h, GWLP_HWNDPARENT, reinterpret_cast<LONG_PTR>(owner));
	return true;
}

int64_t TownWindow::get_owner(int64_t hwnd) {
	HWND h = reinterpret_cast<HWND>(hwnd);
	return IsWindow(h) ? reinterpret_cast<int64_t>(GetWindow(h, GW_OWNER)) : 0;
}
