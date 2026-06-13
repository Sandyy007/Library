import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../models/issue.dart';
import '../utils/hindi_text.dart';
import '../utils/responsive.dart';
import 'common_widgets.dart';

class SearchResultsDialog extends StatelessWidget {
  const SearchResultsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);
    final responsive = Responsive(context);

    return Dialog(
      child: Container(
        width: responsive.dialogWidth(maxDesktop: 850),
        height: responsive.height * 0.8,
        padding: EdgeInsets.all(responsive.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Search Results for "${searchProvider.lastQuery}"',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: searchProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            isScrollable: false,
                            tabs: [
                              Tab(
                                text: 'Books',
                                icon: Icon(Icons.library_books),
                              ),
                              Tab(text: 'Members', icon: Icon(Icons.people)),
                              Tab(text: 'Issues', icon: Icon(Icons.assignment)),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TabBarView(
                                children: [
                                  _buildBooksTab(searchProvider.searchBooks),
                                  _buildMembersTab(
                                    searchProvider.searchMembers,
                                  ),
                                  _buildIssuesTab(searchProvider.searchIssues),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksTab(List<Book> books) {
    if (books.isEmpty) {
      return EmptyStatePresets.noSearchResults();
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final displayTitle = normalizeHindiForDisplay(book.title);
        final displayAuthor = normalizeHindiForDisplay(book.author);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(
              displayTitle,
              style: hindiAwareTextStyle(
                context,
                text: displayTitle,
                base: const TextStyle(),
              ),
            ),
            subtitle: Text(
              'by $displayAuthor • ${book.category ?? 'No category'}',
              style: hindiAwareTextStyle(
                context,
                text: displayAuthor,
                base: const TextStyle(),
              ),
            ),
            trailing: Chip(
              label: Text(book.status),
              backgroundColor: book.status == 'available'
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab(List<Member> members) {
    if (members.isEmpty) {
      return EmptyStatePresets.noSearchResults();
    }

    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final displayName = normalizeHindiForDisplay(member.name);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(
              displayName,
              style: hindiAwareTextStyle(
                context,
                text: displayName,
                base: const TextStyle(),
              ),
            ),
            subtitle: Text(
              '${member.email ?? 'No email'} • ${member.phone ?? 'No phone'}',
            ),
            trailing: Chip(
              label: Text(member.memberTypeLabel),
              backgroundColor:
                  (member.memberType == 'student' ||
                      member.memberType == 'guest')
                  ? const Color(0xFFF59E0B)
                  : member.memberType == 'faculty'
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF10B981),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssuesTab(List<Issue> issues) {
    if (issues.isEmpty) {
      return EmptyStatePresets.noSearchResults();
    }

    return ListView.builder(
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        final displayTitle = normalizeHindiForDisplay(issue.bookTitle);
        final displayAuthor = normalizeHindiForDisplay(issue.bookAuthor);
        final displayMember = normalizeHindiForDisplay(issue.memberName);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(
              displayTitle,
              style: hindiAwareTextStyle(
                context,
                text: displayTitle,
                base: const TextStyle(),
              ),
            ),
            subtitle: Text(
              'by $displayAuthor • Issued to: $displayMember',
              style: hindiAwareTextStyle(
                context,
                text: '$displayAuthor$displayMember',
                base: const TextStyle(),
              ),
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      label: Text(
                        issue.status,
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: issue.status == 'returned'
                          ? const Color(0xFF10B981)
                          : issue.status == 'overdue'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${issue.dueDate}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
