//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "CountryCodeViewController.h"
#import "PhoneNumberUtil.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+OWS.h"

@interface CountryCodeViewController () <OWSTableViewControllerDelegate, UISearchBarDelegate>

@property (nonatomic, readonly) UISearchBar *searchBar;

@property (nonatomic) NSArray<NSString *> *countryCodes;

@end

#pragma mark -

@implementation CountryCodeViewController

- (void)loadView
{
    [super loadView];

    self.view.backgroundColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTranslucent:NO];
    self.title = NSLocalizedString(@"COUNTRYCODE_SELECT_TITLE", @"");

    self.countryCodes = [PhoneNumberUtil countryCodesForSearchTerm:nil];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                      target:self
                                                      action:@selector(dismissWasPressed:)];

    [self createViews];
}

- (void)createViews
{
    // Search
    UISearchBar *searchBar = [UISearchBar new];
    _searchBar = searchBar;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.delegate = self;
    searchBar.placeholder = NSLocalizedString(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", @"");
    searchBar.backgroundColor = [UIColor whiteColor];
    [searchBar sizeToFit];

    self.tableView.tableHeaderView = searchBar;

    [self updateTableContents];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak CountryCodeViewController *weakSelf = self;
    OWSTableSection *section = [OWSTableSection new];

    for (NSString *countryCode in self.countryCodes) {
        OWSAssert(countryCode.length > 0);
        OWSAssert([PhoneNumberUtil countryNameFromCountryCode:countryCode].length > 0);
        OWSAssert([PhoneNumberUtil callingCodeFromCountryCode:countryCode].length > 0);
        OWSAssert(![[PhoneNumberUtil callingCodeFromCountryCode:countryCode] isEqualToString:@"+0"]);

        [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
            UITableViewCell *cell = [UITableViewCell new];
            cell.textLabel.text = [PhoneNumberUtil countryNameFromCountryCode:countryCode];
            cell.textLabel.font = [UIFont ows_regularFontWithSize:18.f];
            cell.textLabel.textColor = [UIColor blackColor];

            UILabel *countryCodeLabel = [UILabel new];
            countryCodeLabel.text = [PhoneNumberUtil callingCodeFromCountryCode:countryCode];
            countryCodeLabel.font = [UIFont ows_regularFontWithSize:16.f];
            countryCodeLabel.textColor = [UIColor ows_darkGrayColor];
            [countryCodeLabel sizeToFit];
            cell.accessoryView = countryCodeLabel;

            return cell;
        }
                             actionBlock:^{
                                 [weakSelf countryCodeWasSelected:countryCode];
                             }]];
    }

    [contents addSection:section];

    self.contents = contents;
}

- (void)countryCodeWasSelected:(NSString *)countryCode
{
    OWSAssert(countryCode.length > 0);

    NSString *callingCodeSelected = [PhoneNumberUtil callingCodeFromCountryCode:countryCode];
    NSString *countryNameSelected = [PhoneNumberUtil countryNameFromCountryCode:countryCode];
    NSString *countryCodeSelected = countryCode;
    [self.countryCodeDelegate countryCodeViewController:self
                                   didSelectCountryCode:countryCodeSelected
                                            countryName:countryNameSelected
                                            callingCode:callingCodeSelected];
    [self.searchBar resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissWasPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self searchTextDidChange];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self searchTextDidChange];
}

- (void)searchTextDidChange
{
    NSString *searchText =
        [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    self.countryCodes = [PhoneNumberUtil countryCodesForSearchTerm:searchText];

    [self updateTableContents];
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewDidScroll
{
    [self.searchBar resignFirstResponder];
}

@end
