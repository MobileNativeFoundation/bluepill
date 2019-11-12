//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "bluepill/src/BPHTMLReportWriter.h"
#import "bluepill/src/BPTestReportHTML.h"

@interface BPHTMLReportWriter (Testing)
/*!
 * @discussion for unit test only. It returns a map of path to content instead of actually writing the files.
 * @param jUnitReport the junit report
 * @param folderPath the output folder path
 */
- (NSDictionary<NSString*, NSString*> *)metaForFileWrites:(NSXMLDocument *)jUnitReport
                                                 inFolder:(nonnull NSString *)folderPath;
@end


@interface BPHTMLReportWriteTests : XCTestCase
@property (nonatomic, strong) NSXMLDocument *junitReport;
@end

@implementation BPHTMLReportWriteTests

- (void)setUp {
    NSError *err;
    NSString *xmlString = [NSString stringWithContentsOfFile:[[[NSBundle bundleForClass:[self class]] resourcePath]
                                                              stringByAppendingPathComponent:@"TEST-FinalReport.xml"]
                                                    encoding:NSUTF8StringEncoding error:&err];

    self.junitReport = [[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:&err];
}

- (void)tearDown {
    self.junitReport = nil;
}

- (void)testHTMLWriter {
    BPHTMLReportWriter *writer = [[BPHTMLReportWriter alloc] init];
    NSDictionary *filesToWrite = [writer metaForFileWrites:self.junitReport inFolder:@"prefix"];
    NSDictionary *expectedFilesToWrite = @{
                                           @"prefix/test-report.js": @"var json = {\n\t\"product\": \"All Tests\",\n\n\t\"testSuites\": [\n\t\t{\n\t\t\t\"testCases\": [\n\t\t\t\t{\n\t\t\t\t\t\"className\": \"PlayerTests\",\n\t\t\t\t\t\"name\": \"testPlayer\",\n\t\t\t\t\t\"failed\": true,\n\t\t\t\t\t\"errors\": [{\"message\": \"-[LearningUITests.PlayerTests testPlayer] : Exception: ActionFailedException\", \"location\": \"\\n/Utilities/TestsHelper/LILTestsHelper.swift:56\\n        \"}],\n\t\t\t\t\t\"artifacts\": [\"failure-logs/PlayerTests.testPlayer.txt\"],\n\n\t\t\t\t\t\"time\": 50.461\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"className\": \"AuthenticationStateHandlerTests\",\n\t\t\t\t\t\"name\": \"testInitWithAuthEngineLoggedOut\",\n\t\t\t\t\t\"failed\": true,\n\t\t\t\t\t\"errors\": [{\"message\": \"Asynchronous wait failed: Exceeded timeout of 2 seconds, with unfulfilled expectations: \\\"Expect wk cookie store has been reset.\\\".\", \"location\": \"\\n<unknown>:0\\n        \"}],\n\t\t\t\t\t\"artifacts\": [\"failure-logs/AuthenticationStateHandlerTests.testInitWithAuthEngineLoggedOut.txt\"],\n\n\t\t\t\t\t\"time\": 10.710\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"className\": \"WebRouterTests\",\n\t\t\t\t\t\"name\": \"testSafariViewControllerGateway\",\n\t\t\t\t\t\"time\": 0.012\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"className\": \"WebRouterTests\",\n\t\t\t\t\t\"name\": \"testWebviewGateway\",\n\t\t\t\t\t\"time\": 0.148\n\t\t\t\t},\n\t\t\t],\n\t\t\t\"name\": \"All Tests\",\n\t\t\t\"numFailures\": 0,\n\t\t\t\"numTests\": 552,\n\t\t\t\"time\": 1058.428,\n\t\t},\n\t],\n}\n",
                                           @"prefix/failure-logs/AuthenticationStateHandlerTests.testInitWithAuthEngineLoggedOut.txt": @"\nXCTestOutputBarrier2019-10-28 13:37:05.678861-0700 Learning[21646:1617371] Invalid connection: com.apple.coresymbolicationd\nInvalid connection: com.apple.coresymbolicationd\n<unknown>:0: error: -[LearningUnitTests.AuthenticationStateHandlerTests testInitWithAuthEngineLoggedOut] : Asynchronous wait failed: Exceeded timeout of 2 seconds, with unfulfilled expectations: \"Expect wk cookie store has been reset.\".\n        ",
                                           @"prefix/0-test-report.html": kHTMLContent,
                                           @"prefix/failure-logs/PlayerTests.testPlayer.txt": @"\nXCTestOutputBarrier2019-10-28 13:37:41.210502-0700 Learning[21976:1621719] [Client] Remote object proxy returned error: Error Domain=NSCocoaErrorDomain Code=4099 \"The connection to service named com.apple.commcenter.coretelephony.xpc was invalidated.\" UserInfo={NSDebugDescription=The connection to service named com.apple.commcenter.coretelephony.xpc was invalidated.}\n        "
                                           };
    XCTAssertEqual([filesToWrite.allKeys count], [expectedFilesToWrite.allKeys count]);
    for (NSString *key in filesToWrite) {
        XCTAssertTrue([filesToWrite[key] isEqualToString:expectedFilesToWrite[key]]);
    }
}

@end
