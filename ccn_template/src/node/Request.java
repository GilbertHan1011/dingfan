package node;

import java.util.LinkedList;
import java.util.List;

/**
 * Created by renfei on 16/3/30.
 */
public class Request {
    public String interest;
    public List<Node> nodeList = new LinkedList<>();
    public static float allHitNum = 0;
    public static int allRqquestNum = 0;

    public Request() {
        Request.allRqquestNum++;
    }
}
