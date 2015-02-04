os = require "os"
fs = require "fs"
path = require "path"
temp = require("temp").track()
{spawn, spawnSync} = require "child_process"
{Builder, By} = require("selenium-webdriver")

AtomPath = '/Applications/Atom.app/Contents/MacOS/Atom'
AtomLauncherPath = path.join(__dirname, "helpers", "atom-launcher.sh")
SocketPath = path.join(os.tmpdir(), "atom-integration-test.sock")
ChromeDriverPort = 9515

describe "Starting Atom", ->
  if spawnSync("type", ["-P", AtomPath]).status isnt 0
    console.log "Skipping integration tests because the `Atom` executable was not in the expected location."
    return

  if spawnSync("type", ["-P", "chromedriver"]).status isnt 0
    console.log "Skipping integration tests because the `chromedriver` executable was not found."
    return

  [chromeDriver, driver, tempDirPath] = []

  beforeEach ->
    tempDirPath = temp.mkdirSync("empty-dir")
    chromeDriver = spawn "chromedriver", ["--verbose", "--port=#{ChromeDriverPort}"]

    # Uncomment to see chromedriver debug output
    # chromeDriver.stderr.on "data", (d) -> console.log(d.toString())

  afterEach ->
    waitsForPromise -> driver.quit().thenFinally(-> chromeDriver.kill())

  startAtom = (args=[]) ->
    driver = new Builder()
      .usingServer("http://localhost:#{ChromeDriverPort}")
      .withCapabilities(
        chromeOptions:
          binary: AtomLauncherPath
          args: [
            "atom-path=#{AtomPath}"
            "atom-args=#{args.join(" ")}"
            "dev"
            "safe"
            "user-data-dir=#{temp.mkdirSync('integration-spec-')}"
            "socket-path=#{SocketPath}"
          ]
      )
      .forBrowser('atom')
      .build()

    waitsForPromise ->
      driver.wait ->
        driver.getTitle().then (title) -> title.indexOf("Atom") >= 0

  describe "when given the name of a file that doesn't exist", ->
    beforeEach ->
      startAtom([path.join(tempDirPath, "new-file")])

    it "opens a new window with an empty text editor", ->
      waitsForPromise ->
        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe("")

        driver.findElement(By.tagName("atom-text-editor")).sendKeys("Hello world!")

        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe("Hello world!")

  describe "when given the name of a file that exists", ->
    beforeEach ->
      existingFilePath = path.join(tempDirPath, "existing-file")
      fs.writeFileSync(existingFilePath, "This was already here.")
      startAtom([existingFilePath])

    it "opens a new window with a text editor for the given file", ->
      waitsForPromise ->
        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe("This was already here.")

  describe "when given the name of a directory that exists", ->
    beforeEach ->
      startAtom([tempDirPath])

    it "opens a new window no text editors open", ->
      waitsForPromise ->
        driver.executeScript(-> atom.workspace.getActiveTextEditor()).then (editor) ->
          expect(editor).toBeNull()
