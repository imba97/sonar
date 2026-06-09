import { LibraryPage } from '../../pages/LibraryPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { ServerPage } from '../../pages/ServerPage';

/** Tab 根页唯一 import 入口，避免 HdsTabsShell / FloatingTabBar 重复拉取同一依赖树 */
@Builder
export function buildLibraryTabPage() {
  LibraryPage()
}

@Builder
export function buildServerTabPage() {
  ServerPage()
}

@Builder
export function buildProfileTabPage() {
  ProfilePage()
}
