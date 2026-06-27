# Who Ate My Space

> 🇬🇧 For English, see [README.md](README.md).

macOS용 디스크 사용량 시각화 도구 — Windows의 [SpaceSniffer](https://www.uderzo.it/main_products/space_sniffer/)에서 영감을 받은 네이티브 SwiftUI 앱.

폴더나 볼륨을 스캔해 파일/폴더를 **용량에 비례하는 트리맵(treemap)** 으로 보여줍니다. 무엇이 디스크를 잡아먹는지 한눈에 확인하고, 바로 휴지통으로 정리할 수 있습니다.

![Who Ate My Space 스크린샷 — 루트(/) 스캔 결과](docs/screenshot.png)

> 루트(`/`)를 스캔한 모습. 폴더 헤더에 이름·용량이 표시되고, 파일은 타입별 색상으로 채워집니다.
> (예: 초록 = 이미지 `Docker.raw`, 자홍 = 디스크 이미지 `rootfs.img`)

## 주요 기능 (v1)

- 폴더/볼륨 병렬 재귀 스캔 (디스크 할당 용량 기준, `du`와 유사)
- Squarified 트리맵 렌더링 (SwiftUI Canvas)
- 파일 타입별 색상 + 범례
- 두 단계 탐색: 폴더 클릭으로 확대(zoom-in), 브레드크럼/한 단계 위 버튼으로 축소
- hover 시 경로/용량 표시, 하이라이트
- 우클릭 메뉴: Finder에서 보기 / 열기 / 경로 복사 / 휴지통으로 이동
- 볼륨 여유·전체 용량 표시
- **시스템 설정 → 저장 공간** 으로 바로 가는 버튼
- 영어 / 한국어 로컬라이즈 (시스템 언어를 따름)

## 실시간이 아닙니다 — 갱신하려면 다시 스캔

트리맵은 **스캔 시점의 스냅샷**이며 실시간 화면이 아닙니다. 스캔 이후 디스크에서 파일이 바뀌어도(Finder에서 삭제, 다운로드 완료, 빌드 산출물 생성 등) 트리맵은 **자동으로 갱신되지 않습니다.**

현재 상태를 보려면 툴바의 **다시 스캔**(↻) 버튼을 누르세요 — 같은 루트로 스캔을 다시 실행합니다. 단, 앱 안에서 항목을 휴지통으로 보낸 경우에는 앱이 그 변경을 알고 있으므로 트리맵이 즉시 갱신됩니다. 그 외의 변경은 다시 스캔이 필요합니다.

## 요구 사항

- macOS 13 (Ventura) 이상
- Xcode 15+
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`)

## 빌드 & 실행

```bash
# 1) Xcode 프로젝트 생성
xcodegen generate

# 2-a) Xcode에서 열어 실행
open WhoAteMySpace.xcodeproj
#     → "My Mac" 타깃 선택 후 Run (⌘R)

# 2-b) 또는 커맨드라인 빌드
xcodebuild -scheme WhoAteMySpace -configuration Debug build

# 테스트
xcodebuild -scheme WhoAteMySpace -destination 'platform=macOS' test
```

## 권한 — 전체 디스크 접근, 허용해도 안전합니다

이 앱은 비샌드박스로 동작합니다. `폴더 선택`으로 고른 폴더는 추가 권한 없이 스캔되지만,
**시스템 보호 영역(다른 사용자 폴더, 일부 시스템 경로 등)** 까지 스캔하려면 전체 디스크 접근 권한이 필요합니다.

> 시스템 설정 → 개인정보 보호 및 보안 → **전체 디스크 접근 권한** → `WhoAteMySpace.app` 추가

**모든 저장소/디스크 권한을 허용해도 안전합니다.** 이 앱이 파일로 하는 일은 트리맵을 그리기 위해 *용량*을 읽는 것뿐입니다. **프로젝트에 네트워크 코드가 전혀 없습니다** — 무엇도 업로드·전송되거나 기기 밖으로 복사되지 않습니다. 소켓을 열지도, HTTP 요청을 보내지도 않으며, 분석/원격 수집(telemetry)도 없습니다. 파일을 건드리는 동작은 사용자가 직접 실행하는 것뿐입니다: Finder에서 보기, 열기, 경로 복사, 휴지통으로 이동. 오픈소스이므로 모든 파일 작업을 직접 확인할 수 있습니다 —
[`Sources/WhoAteMySpace/Utilities/FileActions.swift`](Sources/WhoAteMySpace/Utilities/FileActions.swift) 와
[`Scanner/DiskScanner.swift`](Sources/WhoAteMySpace/Scanner/DiskScanner.swift) 참고.

권한이 없으면 접근 불가 항목은 건너뛰고 계속 진행합니다.

## 배포 (App Store 외부 — dmg)

App Store가 아닌 외부 배포는 **Developer ID 서명 + 공증(notarization)** 이 필요합니다.
(Apple Developer Program 멤버십 $99/년 필요.)

```bash
# 1) Release 빌드 → .app 산출
xcodebuild -scheme WhoAteMySpace -configuration Release \
  -derivedDataPath build clean build

APP="build/Build/Products/Release/WhoAteMySpace.app"

# 2) Developer ID Application 인증서로 서명 (Hardened Runtime 포함)
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" "$APP"

# 3) dmg 패키징
hdiutil create -volname "Who Ate My Space" -srcfolder "$APP" \
  -ov -format UDZO WhoAteMySpace.dmg

# 4) 공증 (앱 암호 또는 키체인 프로파일 사용)
xcrun notarytool submit WhoAteMySpace.dmg \
  --apple-id "you@example.com" --team-id "TEAMID" \
  --password "APP_SPECIFIC_PASSWORD" --wait

# 5) 공증 티켓 첨부 (stapling)
xcrun stapler staple WhoAteMySpace.dmg
```

검증:

```bash
spctl -a -vvv -t install WhoAteMySpace.dmg   # Gatekeeper 통과 확인
codesign -dvvv "$APP"                          # 서명/런타임 확인
```

> Apple Developer 계정이 없으면 개발용 서명으로 로컬 실행까지만 가능합니다.
> 이 경우 dmg를 받은 사용자는 첫 실행 시 우클릭 → "열기"로 Gatekeeper를 우회해야 합니다.

## 다국어 (i18n)

UI는 **영어와 한국어**를 제공하며 시스템 언어를 따릅니다. 문자열은 `.lproj` 번들에 들어 있습니다:

```
Resources/
├── en.lproj/   Localizable.strings · InfoPlist.strings
└── ko.lproj/   Localizable.strings · InfoPlist.strings
```

언어를 추가하려면 번역한 `Localizable.strings` / `InfoPlist.strings`를 담은 `<언어>.lproj` 디렉토리를 만들고, 그 경로를 `project.yml`에 `resources` 빌드 페이즈로 추가한 뒤, `Resources/Info.plist`의 `CFBundleLocalizations`에 언어 코드를 등록하세요.

## 구조

```
Sources/WhoAteMySpace/
├── App/         앱 엔트리 + 최상위 레이아웃
├── Models/      FileNode (트리 노드)
├── Scanner/     DiskScanner (병렬 재귀 스캔)
├── Treemap/     TreemapLayout (squarified) + TreemapRect
├── Views/       TreemapView / Breadcrumb / Legend / ScanProgress
├── ViewModels/  ScanViewModel (상태/네비게이션/파일 작업)
└── Utilities/   FileColor / FileActions / ByteFormat
```

## 한계 / 후속 (v2 후보)

- 필터/검색(크기·확장자·날짜), 제외 패턴
- 실시간 모니터링, 다중 볼륨, 스냅샷 비교
- Quick Look 미리보기
- 같은 볼륨만 스캔(마운트 경계 처리), 하드링크 중복 보정

## 라이선스

[MIT License](LICENSE)로 배포됩니다. © 2026 Jonghoon Park.

## 후원

도움이 되었다면 프로젝트를 후원해 주세요:

<a href="https://github.com/sponsors/dev-jonghoonpark"><img src="https://raw.githubusercontent.com/dev-jonghoonpark/github-style-button-image-generator/refs/heads/main/example/sponsor-button.png" alt="Sponsor" height="32"></a>
