import asyncio, sys, json
from playwright.async_api import async_playwright

URL = "http://127.0.0.1:8080/"
async def main():
    logs = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--use-gl=angle","--use-angle=swiftshader",
            "--enable-unsafe-swiftshader","--no-sandbox","--autoplay-policy=no-user-gesture-required"])
        ctx = await browser.new_context(viewport={"width":1280,"height":720})
        page = await ctx.new_page()
        page.on("console", lambda m: logs.append("[%s] %s" % (m.type, m.text)))
        page.on("pageerror", lambda e: logs.append("[pageerror] %s" % e))
        await page.goto(URL, wait_until="domcontentloaded")
        await asyncio.sleep(20)
        await page.screenshot(path="/home/user/shots/1_menu.png")
        # click the PLAY button (menu column, first entry)
        await page.mouse.click(936, 196)
        await asyncio.sleep(3)
        await page.screenshot(path="/home/user/shots/2_setup.png")
        box = await page.evaluate("() => { const c=document.querySelector('canvas'); const r=c.getBoundingClientRect(); return {x:r.x,y:r.y,w:r.width,h:r.height}; }")
        print(json.dumps(box))
        print("\n".join(logs[-25:]))
        await browser.close()
asyncio.run(main())
