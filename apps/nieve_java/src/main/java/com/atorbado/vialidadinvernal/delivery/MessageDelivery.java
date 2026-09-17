package com.atorbado.vialidadinvernal.delivery;

import java.io.IOException;

public interface MessageDelivery {
    DeliveryReceipt deliver(DeliveryRequest request) throws IOException;
}
