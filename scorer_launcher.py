#!/usr/bin/env python3
"""Öffnet die Scorer-Seite in Firefox, klickt den Knopf (per Text/Selektor statt Pixelposition),
wartet auf das neue Fenster und schiebt es im Vollbild auf den Zielmonitor."""

import argparse
import re
import sys
import time

from selenium import webdriver
from selenium.common.exceptions import (
    ElementClickInterceptedException,
    StaleElementReferenceException,
    TimeoutException,
    WebDriverException,
)
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait

CLICKABLE = "button, a, [role='button'], input[type='button'], input[type='submit'], [onclick]"


def parse_geom(s):
    x, y, w, h = (int(v) for v in s.split())
    return x, y, w, h


def label(el):
    """Sichtbare Beschriftung eines Elements (Text, aria-label, value oder title)."""
    for value in (el.text, el.get_attribute("aria-label"), el.get_attribute("value"), el.get_attribute("title")):
        if value and value.strip():
            return " ".join(value.split())
    return ""


def clickable_elements(driver):
    els = driver.find_elements(By.CSS_SELECTOR, CLICKABLE)
    # Fallback für Single-Page-Apps: Elemente ohne Kindelemente (reine Textknoten-Container)
    els += driver.find_elements(By.XPATH, "//*[not(*) and normalize-space(text()) != '']")
    return els


def find_button(driver, text_re, selector):
    if selector:
        candidates = driver.find_elements(By.CSS_SELECTOR, selector)
    else:
        candidates = clickable_elements(driver)
    for el in candidates:
        try:
            if not (el.is_displayed() and el.is_enabled()):
                continue
            if selector or text_re.search(label(el)):
                return el
        except StaleElementReferenceException:
            continue
    return None


def list_buttons(driver):
    seen = set()
    for el in clickable_elements(driver):
        try:
            if el.is_displayed():
                text = label(el)
                key = (el.tag_name, text)
                if text and key not in seen:
                    seen.add(key)
                    print(f"  <{el.tag_name}> {text!r}")
        except StaleElementReferenceException:
            continue


def click(driver, el):
    try:
        el.click()
    except (ElementClickInterceptedException, WebDriverException):
        driver.execute_script("arguments[0].click();", el)


def place(driver, geom, fullscreen=False):
    x, y, w, h = geom
    driver.set_window_rect(x=x, y=y, width=w, height=h)
    time.sleep(0.5)
    if fullscreen:
        driver.fullscreen_window()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True)
    p.add_argument("--touch-geom", required=True, help='"x y breite hoehe" des Touch-Monitors')
    p.add_argument("--target-geom", required=True, help='"x y breite hoehe" des Zielmonitors')
    p.add_argument("--button-text", default="")
    p.add_argument("--button-selector", default="")
    p.add_argument("--profile", default="")
    p.add_argument("--timeout", type=int, default=60)
    args = p.parse_args()

    touch_geom = parse_geom(args.touch_geom)
    target_geom = parse_geom(args.target_geom)

    opts = Options()
    if args.profile:
        opts.add_argument("-profile")
        opts.add_argument(args.profile)

    driver = webdriver.Firefox(options=opts)
    try:
        driver.get(args.url)
        place(driver, touch_geom)

        # Ohne Text/Selektor: nur anzeigen, was klickbar ist
        if not args.button_text and not args.button_selector:
            time.sleep(10)
            print("Kein BUTTON_TEXT/BUTTON_SELECTOR gesetzt. Klickbare Elemente auf der Seite:")
            list_buttons(driver)
            print("Trage die passende Beschriftung in config.env bei BUTTON_TEXT ein.")
            return 2

        text_re = re.compile(args.button_text, re.IGNORECASE) if args.button_text else None

        try:
            button = WebDriverWait(driver, args.timeout, poll_frequency=0.5).until(
                lambda d: find_button(d, text_re, args.button_selector)
            )
        except TimeoutException:
            print("Knopf nicht gefunden. Klickbare Elemente:", file=sys.stderr)
            list_buttons(driver)
            return 1

        before = set(driver.window_handles)
        click(driver, button)

        try:
            WebDriverWait(driver, args.timeout, poll_frequency=0.5).until(
                lambda d: set(d.window_handles) - before
            )
        except TimeoutException:
            print("Nach dem Klick hat sich kein neues Fenster geöffnet.", file=sys.stderr)
            return 1

        new_handle = (set(driver.window_handles) - before).pop()
        driver.switch_to.window(new_handle)
        place(driver, target_geom, fullscreen=True)
        print("Fenster auf Zielmonitor im Vollbild.")

        # Script am Leben halten: endet es, schließt Selenium den Browser.
        while True:
            time.sleep(2)
            if not driver.window_handles:
                break
    except (WebDriverException, KeyboardInterrupt):
        pass
    finally:
        try:
            driver.quit()
        except WebDriverException:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
