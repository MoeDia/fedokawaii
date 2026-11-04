"""The first screen. (for now: a free game, to see the board drawn)"""
import board as B
from app import Screen
from play import Game
from ui import Row, heading


class Home(Screen):
    def __init__(self):
        self.cursor = 2

    def board(self):
        return B.Position().b, {}, [], False

    def panel(self, w, h):
        return [heading("KNIGHT", "chess", w), "", Row("KNIGHT", "a free game", "1320", act="free")]

    def key(self, name):
        if name == "enter":
            self.app.push(Game({"title": "a free game", "goal": "", "fen": B.START, "colour": 0, "elo": 1320, "clock": (10, 0), "hints": 3, "threats": True, "opponent": "the demon", "no": None}))
        elif name == "esc":
            self.app.pop()
