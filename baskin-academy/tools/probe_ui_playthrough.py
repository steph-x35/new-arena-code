import asyncio, json
from playwright.async_api import async_playwright

async def main():
    logs = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader",
            "--enable-unsafe-swiftshader","--no-sandbox","--autoplay-policy=no-user-gesture-required"])
        ctx = await browser.new_context(viewport={"width":1280,"height":720})
        page = await ctx.new_page()
        page.on("console", lambda m: logs.append("[%s] %s" % (m.type, m.text)))
        page.on("pageerror", lambda e: logs.append("[pageerror] %s" % e))
        await page.goto("http://127.0.0.1:8080/", wait_until="domcontentloaded")
        await asyncio.sleep(22)
        await page.screenshot(path="/home/user/shots/1_menu.png")
        await page.mouse.click(936, 196)          # GIOCA · PARTITA INDOOR
        await asyncio.sleep(3)
        await page.screenshot(path="/home/user/shots/2_setup.png")
        await page.mouse.click(876, 654)          # TIP OFF
        await asyncio.sleep(8)
        await page.screenshot(path="/home/user/shots/3_intro.png")
        await page.mouse.click(640, 640)          # tap to skip the intro card
        await asyncio.sleep(12)
        await page.screenshot(path="/home/user/shots/4_game.png")
        await asyncio.sleep(10)
        await page.screenshot(path="/home/user/shots/5_game2.png")
        print("\n".join(logs[-30:]))
        await browser.close()
asyncio.run(main())
