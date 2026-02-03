import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../models/issue.dart';
import '../utils/hindi_text.dart';

class SearchResultsDialog extends StatelessWidget {
  const SearchResultsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Search Results for "${searchProvider.lastQuery}"',
                  style: Theme.of(context).textTheme.headlineSmall,
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
      return const Center(child: Text('No books found'));
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
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab(List<Member> members) {
    if (members.isEmpty) {
      return const Center(child: Text('No members found'));
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
                  ? Colors.orange
                  : member.memberType == 'faculty'
                  ? Colors.purple
                  : Colors.green,
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssuesTab(List<Issue> issues) {
    if (issues.isEmpty) {
      return const Center(child: Text('No issues found'));
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
            trailing: SizedBox(
              width: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    label: Text(issue.status),
                    backgroundColor: issue.status == 'returned'
                        ? Colors.green
                        : issue.status == 'overdue'
                        ? Colors.red
                        : Colors.orange,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${issue.dueDate}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
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
