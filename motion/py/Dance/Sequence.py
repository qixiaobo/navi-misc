""" Sequence

Map a sequence to a chaotic attractor and shuffle it.
"""

import Numeric, math
from ODE import RK4, Time

__all__ = ["Sequence"]


class Sequence:
    """This class represents a dance sequence mapped to an attractor."""
    def __init__ (self, system, ic, t, data):
        """Each Sequence object requires an ordinary differential equation
           solver and some motion capture data (data).
           """
        self.mapping = {}
        self.ode = RK4 (system)

        if isinstance (t, Time):
            self.t = t
        else:
            start, iterations, step = t
            self.t = Time (start, iterations, step)

        traj = self.ode (ic, self.t)

        frames = len (data.values ()[0])
        step = len (traj) / frames
        length = frames * step

        # Map each frame evenly over the trajectory.
        for i in range (frames):
            self.mapping[_Coordinate (traj[i * step])] = _Frame (i, data)

    def __getitem__ (self, frame):
        """Use [] on a Sequence object to get a frame."""
        return self.mapping.items () [frame]

    def _distance (self, x, y):
        """Calculate the Euclidean distance between the points x and y."""
        return math.sqrt (Numeric.sum ((y - x)**2))

    def _findNearest (self, point):
        """Find a point the trajectory nearest to the coordinate given."""
        traj = self.mapping.keys ()
        frames = self.mapping.items ()
        dist = self._distance (traj[0], point)
        winner = frames[0]

        for i in range (1, len (traj)):
            delta = self._distance (traj[i], point)
            if delta < dist:
                dist = delta
                winner = frames[i]

        return winner

    def shuffle (self, ics, time=None):
        """ Takes a set of initial conditions (ics) and returns a new
            dance sequence.
            """
        shuffled = []
        traj = self.ode (ics, time or self.t)
        step = len (traj) / len (self.mapping.keys ())
        length = len (traj) * step

        for i in range (length):
            shuffled.append (self._findNearest (traj[i]))

        return shuffled

    def save (self):
        """ Store the sequence to a file. """
        # FIXME
        pass


class _Coordinate:
    """A hashable coordinate object."""
    def __init__ (self, coords):
        self.coordinates = Numeric.array (coords)

    def __cmp__ (self, other):
        if math.sqrt (Numeric.sum (self.coordinates**2)) < \
                math.sqrt (Numeric.sum (other.coordinates**2)):
            return -1
        else:
            i = iter (other.coordinates)
            for coord in self.coordinates:
                if coord != i.next():
                    return 1

        return 0

    def __hash__ (self):
        h = 0
        for coord in self.coordinates:
            h = h ^ hash (coord)
        return h


class _Frame:
    """A frame from the AMC file."""
    def __init__ (self, index, data):
        # Map bone names to a list of values in a single frame. Each value
        # corresponds to a degree of freedom for that bone. index gives the
        # frame number and data is a dictionary mapping bones to motion data.
        # The movement data is stored as follows: data["bone name"][frame, dof].
        self.__bones = {}

        for bone, values in data.iteritems ():
            self.__bones[bone] = values[index]

    def __getitem__ (self, bone):
        return self.__bones[bone]


# vim:ts=4:sw=4:et:tw=80
